#!/bin/bash

source /root/admin-login

read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
echo

# 设置 keystone 数据库的密码
read -s -p "Set your db_keystone password: " KEYSTONE_DBPASS
echo

# 设置 OpenStack 管理员 admin 的密码
read -s -p "Set your admin password: " ADMIN_PASSWORD
echo

CONFIG_FILE="/etc/keystone/keystone.conf"
CONFIG_OPTION_DATABASE="connection = mysql+pymysql://keystone:$KEYSTONE_DBPASS@controller/keystone"
CONFIG_OPTION_TOKEN="provider = fernet"

# 安装 openstack-keystone 包
yum install -y openstack-keystone httpd mod_wsgi
if [ $? -ne 0 ]; then
    echo "Failed to install package openstack-keystone."
    exit 1
fi
echo "Package openstack-keystone installed successfully."

# 删除已有的数据库
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS keystone;"
if [ $? -ne 0 ]; then
    echo "Failed to delete existing keystone database."
    exit 1
fi
echo "Existing keystone database deleted."

# 创建新的数据库和用户
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<MYSQL_SCRIPT
CREATE DATABASE keystone; 
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';
MYSQL_SCRIPT

if [ $? -ne 0 ]; then
    echo "Failed to perform database operations."
    exit 1
fi
echo "Database operations completed successfully."

# 同步数据库
echo "Syncing keystone database..."
su keystone -s /bin/sh -c "keystone-manage db_sync"
if [ $? -ne 0 ]; then
    echo "Database sync failed."
    exit 1
fi
echo "Database sync completed successfully."

# 更新配置文件
sed -i "/^\[database\]$/a $CONFIG_OPTION_DATABASE" "$CONFIG_FILE"
sed -i "/^\[token\]$/a $CONFIG_OPTION_TOKEN" "$CONFIG_FILE"

# 初始化 Fernet 密钥
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
if [ $? -ne 0 ]; then
    echo "Fernet initialization failed."
    exit 1
fi
echo "Fernet initialization finished."

# 初始化证书
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
if [ $? -ne 0 ]; then
    echo "Credential setup failed."
    exit 1
fi
echo "Credential setup finished."

# 启动 Keystone 服务
keystone-manage bootstrap --bootstrap-password $ADMIN_PASSWORD --bootstrap-admin-url http://controller:5000/v3 --bootstrap-internal-url http://controller:5000/v3 --bootstrap-public-url http://controller:5000/v3 --bootstrap-region-id RegionOne
if [ $? -ne 0 ]; then
    echo "User initialization failed."
    exit 1
fi
echo "User initialization finished."

# 配置 Apache
if [ -e /etc/httpd/conf.d/wsgi-keystone.conf ]; then
    rm /etc/httpd/conf.d/wsgi-keystone.conf
    echo "Existing /etc/httpd/conf.d/wsgi-keystone.conf removed."
fi
ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
echo "Symlink /etc/httpd/conf.d/wsgi-keystone.conf created."

sed -i 's/^#ServerName.*/ServerName controller/' /etc/httpd/conf/httpd.conf
if [ $? -ne 0 ]; then
    echo "Failed to configure Apache ServerName."
    exit 1
fi
echo "Apache ServerName configured."

systemctl enable httpd
systemctl start httpd
if [ $? -ne 0 ]; then
    echo "Failed to start Apache."
    exit 1
fi
echo "Apache started successfully."

# 创建 admin-login 脚本
cat << EOF > /root/admin-login
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASSWORD
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
echo "Admin login script created successfully."

# 加载环境变量
if [ $? -ne 0 ]; then
    echo "Failed to import environment variables."
    exit 1
fi
echo "Environment variables were successfully imported."

# 创建项目和角色
openstack project create --domain default project
if [ $? -ne 0 ]; then
    echo "Failed to create project."
    exit 1
fi
echo "Project created successfully."

openstack role create user
if [ $? -ne 0 ]; then
    echo "Failed to create role."
    exit 1
fi
echo "Role created successfully."

echo "OpenStack Keystone has been installed and configured successfully."

#作者：@Dzzan
#E-mail：d3zzan@gmail.com
