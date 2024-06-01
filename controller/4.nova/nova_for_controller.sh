#!/bin/bash

source /root/admin-login

source /tmp/openstack_needed_passwords_1

source /tmp/openstack_needed_passwords_2

source /tmp/ip

CONFIG_FILE="/etc/nova/nova.conf"
CONFIG_OPTION_API_DATABASE="connection = mysql+pymysql://nova:$NOVA_API_DBPASS@controller/nova_api"
CONFIG_OPTION_DATABASE="connection = mysql+pymysql://nova:$NOVA_DBPASS@controller/nova"
CONFIG_OPTION_API="auth_strategy = keystone"
CONFIG_OPTION_KEYSTONE_AUTHTOKEN=$(cat <<EOF
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = project
username = nova
password = $NOVA_PASS
EOF
)
CONFIG_OPTION_PLACEMENT=$(cat <<EOF
auth_url = http://controller:5000
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = project
username = placement
password = $PLACEMENT_PASS
region_name = RegionOne
EOF
)
CONFIG_OPTION_GLANCE="api_servers = http://controller:9292"
CONFIG_OPTION_OSLO_CONCURRENCY="lock_path = /var/lib/nova/tmp"
CONFIG_OPTION_DEFAULT=$(cat <<EOF
enabled_apis = osapi_compute,metadata
transport_url = rabbit://rabbitmq:$RABBITMQ_PASSWORD@controller:5672
my_ip = $MY_IP
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver
EOF
)
CONFIG_OPTION_VNC=$(cat <<EOF
enabled = true
server_listen = $IP_CONTROLLER_INTERNAL
server_proxyclient_address = $IP_CONTROLLER_INTERNAL
EOF
)
CONFIG_OPTION_SCHEDULER="discover_hosts_in_cells_interval = 60"

# 安装必要的 Nova 包
yum install -y openstack-nova-api openstack-nova-conductor openstack-nova-scheduler openstack-nova-novncproxy
if [ $? -ne 0 ]; then
    echo "Failed to install OpenStack Nova packages."
    exit 1
else
    echo "OpenStack Nova packages installed successfully."
fi

# 删除现有的 Nova 数据库
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS nova_api; DROP DATABASE IF EXISTS nova_cell0; DROP DATABASE IF EXISTS nova;"
if [ $? -ne 0 ]; then
    echo "Failed to delete existing Nova databases."
    exit 1
else
    echo "Existing Nova databases deleted."
fi

# 创建新的 Nova 数据库并授予权限
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<MYSQL_SCRIPT
CREATE DATABASE nova_api;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_API_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_API_DBPASS';

CREATE DATABASE nova_cell0;
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_CELL0_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_CELL0_DBPASS';

CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
MYSQL_SCRIPT

if [ $? -ne 0 ]; then
    echo "Failed to create and grant privileges on Nova databases."
    exit 1
else
    echo "Nova databases created and privileges granted successfully."
fi

# 备份和修改 nova.conf 配置文件
cp /etc/nova/nova.conf /etc/nova/nova.conf.bak
grep -Ev '^$|#' /etc/nova/nova.conf.bak > /etc/nova/nova.conf

# 修改 nova.conf
sed -i "/^\[api_database\]$/a $CONFIG_OPTION_API_DATABASE" "$CONFIG_FILE"
sed -i "/^\[database\]$/a $CONFIG_OPTION_DATABASE" "$CONFIG_FILE"
sed -i "/^\[api\]$/a $CONFIG_OPTION_API" "$CONFIG_FILE"
sed -i "/^\[keystone_authtoken\]$/a $CONFIG_OPTION_KEYSTONE_AUTHTOKEN" "$CONFIG_FILE"
sed -i "/^\[placement\]$/a $CONFIG_OPTION_PLACEMENT" "$CONFIG_FILE"
sed -i "/^\[glance\]$/a $CONFIG_OPTION_GLANCE" "$CONFIG_FILE"
sed -i "/^\[oslo_concurrency\]$/a $CONFIG_OPTION_OSLO_CONCURRENCY" "$CONFIG_FILE"
sed -i "/^\[DEFAULT\]$/a $CONFIG_OPTION_DEFAULT" "$CONFIG_FILE"
sed -i "/^\[vnc\]$/a $CONFIG_OPTION_VNC" "$CONFIG_FILE"
sed -i "/^\[scheduler\]$/a $CONFIG_OPTION_SCHEDULER" "$CONFIG_FILE"

# 同步数据库
echo "Syncing Nova databases..."
su nova -s /bin/sh -c "nova-manage api_db sync" || { echo "Failed to sync api_db"; exit 1; }
su nova -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1" || { echo "Failed to create cell1"; exit 1; }
su nova -s /bin/sh -c "nova-manage cell_v2 map_cell0" || { echo "Failed to map cell0"; exit 1; }
su nova -s /bin/sh -c "nova-manage db sync" || { echo "Failed to sync db"; exit 1; }
echo "Database sync completed successfully."

# 列出 cells
nova-manage cell_v2 list_cells

# 设置 OpenStack 用户、角色、服务和端点
openstack user create --domain default --password "$NOVA_PASS" nova || { echo "Failed to create nova user"; exit 1; }
if [ $? -ne 0 ]; then
    echo "Failed to create nova user."
    exit 1
fi
echo "Nova user created successfully."

openstack role add --project project --user nova admin
if [ $? -ne 0 ]; then
    echo "Failed to add role to nova user."
    exit 1
fi
echo "Role added to nova user successfully."

openstack service create --name nova --description "OpenStack Compute" compute
if [ $? -ne 0 ]; then
    echo "Failed to create nova service."
    exit 1
fi
echo "Nova service created successfully."

openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
if [ $? -ne 0 ]; then
    echo "Failed to create public endpoint for nova."
    exit 1
fi
echo "Public endpoint for nova created successfully."

openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
if [ $? -ne 0 ]; then
    echo "Failed to create internal endpoint for nova."
    exit 1
fi
echo "Internal endpoint for nova created successfully."

openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1
if [ $? -ne 0 ]; then
    echo "Failed to create admin endpoint for nova."
    exit 1
fi
echo "Admin endpoint for nova created successfully."

# 启用 Nova 服务
systemctl enable openstack-nova-api openstack-nova-scheduler openstack-nova-conductor openstack-nova-novncproxy

#重启Nova服务
echo "Nova services restarting..."
systemctl restart openstack-nova-api openstack-nova-scheduler openstack-nova-conductor openstack-nova-novncproxy
if [ $? -ne 0 ]; then
    echo "Failed to restart Nova services."
    exit 1
else
    echo "Nova services restarted successfully."
fi


#作者：@Dzzan
#E-mail：d3zzan@gmail.com 
