#!/bin/bash

source /root/admin-login

# 获取用户数据库 root 密码
read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
echo

# 获取 KeyStone 用户 Cinder 密码
read -s -p "Enter your cinder password: " CINDER_PASS
echo

# 设置数据库 Cinder 密码
read -s -p "Set your db_cinder password: " CINDER_DBPASS
echo

# 针对 cinder.conf 的配置
CONFIG_FILE_1="/etc/cinder/cinder.conf"
CONFIG_OPTION_DATABASE="connection = mysql+pymysql://cinder:$CINDER_DBPASS@controller/cinder"
CONFIG_OPTION_DEFAULT=$(cat <<EOF
auth_strategy = keystone
transport_url = rabbit://rabbitmq:000000@controller:5672
EOF
)
CONFIG_OPTION_KEYSTONE_AUTHTOKEN=$(cat <<EOF
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = project
username = cinder
password = $CINDER_PASS
EOF
)
CONFIG_OPTION_OSLO_CONCURRENCY="lock_path = /var/lib/cinder/tmp"

# 针对 nova.conf 的配置
CONFIG_FILE_2="/etc/nova/nova.conf"
CONFIG_OPTION_CINDER="os_region_name = RegionOne"

# 安装 OpenStack Cinder
yum -y install openstack-cinder
if [ $? -ne 0 ]; then
    echo "Failed to install openstack-cinder."
    exit 1
else
    echo "openstack-cinder installed successfully."
fi

#删除现有 Cinder 数据库 
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS cinder;"
if [ $? -ne 0 ]; then
    echo "Failed to delete existing cinder database."
    exit 1
fi
echo "Existing cinder database deleted."

# 配置 MariaDB 数据库
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<MYSQL_SCRIPT
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$CINDER_DBPASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$CINDER_DBPASS';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

if [ $? -ne 0 ]; then
    echo "Failed to configure the Cinder database."
    exit 1
else
    echo "Cinder database configured successfully."
fi

# 备份 cinder.conf
cp /etc/cinder/cinder.conf /etc/cinder/cinder.bak
if [ $? -ne 0 ]; then
    echo "Failed to backup cinder.conf."
    exit 1
else
    echo "Backup of cinder.conf created successfully."
fi

# 去掉所有注释和空行
grep -Ev '^$|#' /etc/cinder/cinder.bak > /etc/cinder/cinder.conf
if [ $? -ne 0 ]; then
    echo "Failed to clean cinder.conf."
    exit 1
else
    echo "cinder.conf cleaned successfully."
fi

# 修改 cinder.conf 配置
sed -i "/^\[database\]$/a $CONFIG_OPTION_DATABASE" $CONFIG_FILE_1
sed -i "/^\[DEFAULT\]$/a $CONFIG_OPTION_DEFAULT" $CONFIG_FILE_1
sed -i "/^\[keystone_authtoken\]$/a $CONFIG_OPTION_KEYSTONE_AUTHTOKEN" $CONFIG_FILE_1
sed -i "/^\[oslo_concurrency\]$/a $CONFIG_OPTION_OSLO_CONCURRENCY" $CONFIG_FILE_1

#修改 nova.conf 配置
sed -i "/^\[cinder\]$/a $CONFIG_OPTION_CINDER" $CONFIG_FILE_2

# 同步 Cinder 数据库
su -s /bin/sh -c "cinder-manage db sync" cinder
if [ $? -ne 0 ]; then
    echo "Failed to synchronize Cinder database."
    exit 1
else
    echo "Cinder database synchronized successfully."
fi

# 创建 Cinder 用户和服务
openstack user create --domain default --password $CINDER_PASS cinder
if [ $? -ne 0 ]; then
    echo "Failed to create Cinder user."
    exit 1
else
    echo "Cinder user created successfully."
fi

openstack role add --project project --user cinder admin
if [ $? -ne 0 ]; then
    echo "Failed to add admin role to Cinder user."
    exit 1
else
    echo "Admin role added to Cinder user successfully."
fi

openstack service create --name cinderv3 volumev3
if [ $? -ne 0 ]; then
    echo "Failed to create Cinder service."
    exit 1
else
    echo "Cinder service created successfully."
fi

# 创建服务端点
openstack endpoint create --region RegionOne volumev3 public http://controller:8776/v3/%\(project_id\)s
if [ $? -ne 0 ]; then
    echo "Failed to create public endpoint for Cinder."
    exit 1
else
    echo "Public endpoint for Cinder created successfully."
fi

openstack endpoint create --region RegionOne volumev3 internal http://controller:8776/v3/%\(project_id\)s
if [ $? -ne 0 ]; then
    echo "Failed to create internal endpoint for Cinder."
    exit 1
else
    echo "Internal endpoint for Cinder created successfully."
fi

openstack endpoint create --region RegionOne volumev3 admin http://controller:8776/v3/%\(project_id\)s
if [ $? -ne 0 ]; then
    echo "Failed to create admin endpoint for Cinder."
    exit 1
else
    echo "Admin endpoint for Cinder created successfully."
fi

# 重启 Nova API 服务
echo "Nova service restarting...."
systemctl restart openstack-nova-api
if [ $? -ne 0 ]; then
    echo "Failed to restart Nova API service."
    exit 1
else
    echo "Nova API service restarted successfully."
fi

# 启用 Cinder 服务
systemctl enable openstack-cinder-api openstack-cinder-scheduler
if [ $? -ne 0 ]; then
    echo "Failed to enable Cinder services."
    exit 1
else
    echo "Cinder services enabled successfully."
fi

#重启 Cinder 服务
echo "Cinder service restarting..."
systemctl restart openstack-cinder-api openstack-cinder-scheduler
if [ $? -ne 0 ]; then
    echo "Failed to restart Cinder services."
    exit 1
else
    echo "Cinder services restarted successfully."
fi

echo "OpenStack Cinder has been installed and configured successfully."

#作者：@Dzzan
#E-mail：d3zzan@gmail.com
