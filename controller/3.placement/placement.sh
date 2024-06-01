#!/bin/bash

source /root/admin-login

source /tmp/openstack_needed_passwords_1

source /tmp/openstack_needed_passwords_2

CONFIG_FILE="/etc/placement/placement.conf"
CONFIG_OPTION_PLACEMENT_DATABASE="connection = mysql+pymysql://placement:$PLACEMENT_DBPASS@controller/placement"
CONFIG_OPTION_API="auth_strategy = keystone"
CONFIG_OPTION_KEYSTONE_AUTHTOKEN=$(cat <<EOF
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = project
username = placement
password = $PLACEMENT_PASS
EOF
)
CONFIG_HTTPD_FILE="/etc/httpd/conf.d/00-placement-api.conf"
CONFIG_OPTION_HTTPD=$(cat <<EOF
<Directory /usr/bin>
    Require all granted
</Directory>
EOF
)

# 安装 openstack-placement-api 包
yum install -y openstack-placement-api
if [ $? -ne 0 ]; then
    echo "Failed to install package openstack-placement-api."
    exit 1
fi
echo "Package openstack-placement-api installed successfully."

# 删除现有 placement 数据库
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS placement;"
if [ $? -ne 0 ]; then
    echo "Failed to delete existing placement database."
    exit 1
fi
echo "Existing placement database deleted."

# 创建 placement 数据库
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<MYSQL_SCRIPT
CREATE DATABASE placement;
GRANT ALL PRIVILEGES ON placement.* TO placement@'localhost' IDENTIFIED BY '$PLACEMENT_DBPASS';
GRANT ALL PRIVILEGES ON placement.* TO placement@'%' IDENTIFIED BY '$PLACEMENT_DBPASS';
MYSQL_SCRIPT

if [ $? -ne 0 ]; then
    echo "Failed to create placement database."
    exit 1
fi
echo "Placement database created successfully."

# 备份与修改Placement配置文件
cp /etc/placement/placement.conf /etc/placement/placement.bak
grep -Ev '^$|#' /etc/placement/placement.bak > /etc/placement/placement.conf

# 修改 placement.conf
sed -i "/^\[placement_database\]$/a $CONFIG_OPTION_PLACEMENT_DATABASE" "$CONFIG_FILE"
sed -i "/^\[api\]$/a $CONFIG_OPTION_API" "$CONFIG_FILE"
sed -i "/^\[keystone_authtoken\]$/a $CONFIG_OPTION_KEYSTONE_AUTHTOKEN" "$CONFIG_FILE"

# 更新 httpd 配置
sed -i "/^\<VirtualHost\>$/a $CONFIG_OPTION_HTTPD" "$CONFIG_HTTPD_FILE"

# 同步数据库
echo "Syncing placement database..."
su placement -s /bin/sh -c "placement-manage db sync"
if [ $? -ne 0 ]; then
    echo "Failed to sync placement database."
    exit 1
fi
echo "Database sync completed successfully."

# 设置 OpenStack 用户、角色、服务和端点
. admin-login
openstack user create --domain default --password "$PLACEMENT_PASS" placement
if [ $? -ne 0 ]; then
    echo "Failed to create placement user."
    exit 1
fi
echo "Placement user created successfully."

openstack role add --project project --user placement admin
if [ $? -ne 0 ]; then
    echo "Failed to add role to placement user."
    exit 1
fi
echo "Role added to placement user successfully."

openstack service create --name placement --description "Placement API" placement
if [ $? -ne 0 ]; then
    echo "Failed to create placement service."
    exit 1
fi
echo "Placement service created successfully."

openstack endpoint create --region RegionOne placement public http://controller:8778
if [ $? -ne 0 ]; then
    echo "Failed to create public endpoint for placement."
    exit 1
fi
echo "Public endpoint for placement created successfully."

openstack endpoint create --region RegionOne placement internal http://controller:8778
if [ $? -ne 0 ]; then
    echo "Failed to create internal endpoint for placement."
    exit 1
fi
echo "Internal endpoint for placement created successfully."

openstack endpoint create --region RegionOne placement admin http://controller:8778
if [ $? -ne 0 ]; then
    echo "Failed to create admin endpoint for placement."
    exit 1
fi
echo "Admin endpoint for placement created successfully."

# 重启 httpd 服务
echo "Httpd service restarting..."
systemctl restart httpd
if [ $? -ne 0 ]; then
    echo "Failed to restart httpd service."
    exit 1
fi
echo "Httpd service restarted successfully."


#作者：@Dzzan
#E-mail：d3zzan@gmail.com                        
