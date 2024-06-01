#!/bin/bash

source /root/admin-login

source /tmp/openstack_needed_passwords_1

source /tmp/openstack_needed_passwords_2

CONFIG_FILE="/etc/glance/glance-api.conf"
CONFIG_OPTION_DATABASE="connection = mysql+pymysql://glance:$GLANCE_DBPASS@controller/glance"
CONFIG_OPTION_KEYSTONE_AUTHTOKEN=$(cat <<EOF
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
username = glance
password = $GLANCE_PASS
project_name = project
user_domain_name = Default
project_domain_name = Default
EOF
)
CONFIG_OPTION_GLANCE_STORE=$(cat <<EOF
stores = file
default_store = file
filesystem_store_datadir = /var/lib/glance/images/
EOF
)
CONFIG_OPTION_PASTE_DEPLOY="flavor = keystone"

# 安装 openstack-glance
yum -y install openstack-glance
if [ $? -ne 0 ]; then
    echo "Failed to install package openstack-glance."
    exit 1
fi
echo "Package openstack-glance installed successfully."

# 删除现有 glance 数据库
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS glance;"
if [ $? -ne 0 ]; then
    echo "Failed to delete existing glance database."
    exit 1
fi
echo "Glance database deleted successfully."

# 创建 glance 数据库
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<MYSQL_SCRIPT
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';
MYSQL_SCRIPT

if [ $? -ne 0 ]; then
    echo "Failed to create glance database."
    exit 1
fi
echo "Glance database created successfully."

# 备份和修改Glance配置文件
cp /etc/glance/glance-api.conf /etc/glance/glance-api.bak
grep -Ev '^$|#' /etc/glance/glance-api.bak > /etc/glance/glance-api.conf

# 修改 glance-api.conf
sed -i "/^\[database\]$/a $CONFIG_OPTION_DATABASE" "$CONFIG_FILE"
sed -i "/^\[keystone_authtoken\]$/a $CONFIG_OPTION_KEYSTONE_AUTHTOKEN" "$CONFIG_FILE"
sed -i "/^\[glance_store\]$/a $CONFIG_OPTION_GLANCE_STORE" "$CONFIG_FILE"
sed -i "/^\[paste_deploy\]$/a $CONFIG_OPTION_PASTE_DEPLOY" "$CONFIG_FILE"

# 同步数据库
echo "Syncing glance database..."
su glance -s /bin/sh -c "glance-manage db_sync"
if [ $? -ne 0 ]; then
    echo "Failed to sync glance database."
    exit 1
fi
echo "Database sync completed successfully."

# 创建 Glance 用户、分配角色、创建服务和端点
openstack user create --domain default --password $GLANCE_PASS glance
if [ $? -ne 0 ]; then
    echo "Failed to create glance user."
    exit 1
fi
echo "Glance user created successfully."

openstack role add --project project --user glance admin
if [ $? -ne 0 ]; then
    echo "Failed to add role to glance user."
    exit 1
fi
echo "Role added to glance user successfully."

openstack service create --name glance image
if [ $? -ne 0 ]; then
    echo "Failed to create glance service."
    exit 1
fi
echo "Glance service created successfully."

openstack endpoint create --region RegionOne glance public http://controller:9292
if [ $? -ne 0 ]; then
    echo "Failed to create public endpoint for glance."
    exit 1
fi
echo "Public endpoint for glance created successfully."

openstack endpoint create --region RegionOne glance internal http://controller:9292
if [ $? -ne 0 ]; then
    echo "Failed to create internal endpoint for glance."
    exit 1
fi
echo "Internal endpoint for glance created successfully."

openstack endpoint create --region RegionOne glance admin http://controller:9292
if [ $? -ne 0 ]; then
    echo "Failed to create admin endpoint for glance."
    exit 1
fi
echo "Admin endpoint for glance created successfully."

# 启用和启动 Glance 服务
echo "Starting glance service..."
systemctl enable openstack-glance-api
systemctl start openstack-glance-api
if [ $? -ne 0 ]; then
    echo "Failed to start glance service."
    exit 1
fi
echo "Glance service started successfully."


#作者：@Dzzan
#E-mail：d3zzan@gmail.com
