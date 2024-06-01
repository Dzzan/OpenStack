#!/bin/bash

read -p "Enter yout controller internal ip: " CONTROLLER_INTERNAL_IP
echo

read -s -p "Enter RabbitMQ password: " RABBIT_PASS
echo

#Chrony 时间同步

CONFIG_FILE="/etc/chrony.conf"

# 编辑Chrony配置文件
echo "Configuring Chrony on compute node..."

# 删除默认的NTP服务器
sed -i '/server 0.centos.pool.ntp.org iburst/d' $CONFIG_FILE
sed -i '/server 1.centos.pool.ntp.org iburst/d' $CONFIG_FILE
sed -i '/server 2.centos.pool.ntp.org iburst/d' $CONFIG_FILE
sed -i '/server 3.centos.pool.ntp.org iburst/d' $CONFIG_FILE

# 增加控制节点的NTP服务器
echo "server controller iburst" >> $CONFIG_FILE

# 重启Chrony服务使配置生效
echo "Chronyd service restarting..."
systemctl restart chronyd
if [ $? -ne 0 ]; then
    echo "Failed to restart chronyd service on compute node."
    exit 1
fi

echo "Chrony configuration on compute node completed successfully."

# 配置控制节点的Chrony服务器
echo "Configuring Chrony on controller node..."

# OpenStack云计算平台基础框架

yum -y install centos-release-openstack-train
if [ $? -ne 0 ]; then
    echo "Failed to install centos-release-openstack-train." 
    exit 1
fi
echo "centos-release-openstack-train installed successfully."

#删除没用的YUM源
rm -rf /etc/yum.repos.d/C*.repo

#升级的软件包
echo "upgrading yum sources"
yum upgrade -y
if [ $? -ne 0 ]; then
    echo "Failed to upgrade yum sources." 
    exit 1
fi
echo "upgrading yum sources successfully."


rm -rf /etc/yum.repos.d/C*.repo

#安装OpenStack云计算平台管理客户端
yum  -y install python-openstackclient
if [ $? -ne 0 ]; then
    echo "Failed to install python-openstackclient." 
    exit 1
fi
echo "python-openstackclient installed successfully."


#安装OpenStack SELinux安全策略
yum -y install openstack-selinux
if [ $? -ne 0 ]; then
    echo "Failed to install openstack-selinux." 
    exit 1
fi
echo "openstack-selinux installed successfully."


#安装MariaDB数据库服务


# 安装 MariaDB 和 python2-PyMySQL
yum install -y mariadb-server python2-PyMySQL
if [ $? -ne 0 ]; then
    echo "Failed to install mariadb-server or python2-PyMySQL." 
    exit 1
fi
echo "MariaDB and python2-PyMySQL installed successfully."

# 创建 /etc/my.cnf.d/openstack.cnf 配置文件
CONFIG_FILE_CNF="/etc/my.cnf.d/openstack.cnf"
cat > "$CONFIG_FILE_CNF" <<EOF
[mysqld]
bind-address = $CONTROLLER_INTERNAL_IP
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF
if [ $? -ne 0 ]; then
    echo "Failed to create $CONFIG_FILE."
    exit 1
fi
echo "MariaDB configuration file created successfully at $CONFIG_FILE."

# 设置 MariaDB 开机启动并立即启动服务
systemctl enable mariadb
if [ $? -ne 0 ]; then
    echo "Failed to enable mariadb service."
    exit 1
fi
echo "MariaDB service enabled to start on boot."

echo "mariadb restarting..."
systemctl restart mariadb
if [ $? -ne 0 ]; then
    echo "Failed to start mariadb service."
    exit 1
fi
echo "MariaDB service started successfully."

# 执行 mysql_secure_installation
echo "Running mysql_secure_installation..."
mysql_secure_installation

# 提示用户完成设置
echo "Please follow the prompts to complete the mysql_secure_installation setup."

echo "MariaDB installation and configuration completed successfully."

#安装 RabbitMQ 消息队列服务

# 安装 RabbitMQ
yum -y install rabbitmq-server
if [ $? -ne 0 ]; then
    echo "Failed to install rabbitmq-server."
    exit 1
fi
echo "RabbitMQ server installed successfully."

# 启动 RabbitMQ 服务并设置开机启动
systemctl enable rabbitmq-server
if [ $? -ne 0 ]; then
    echo "Failed to enable rabbitmq-server."
    exit 1
fi
echo "RabbitMQ server enabled to start on boot."

echo "rabbitmq-server restarting..."
systemctl restart rabbitmq-server
if [ $? -ne 0 ]; then
    echo "Failed to restart rabbitmq-server."
    exit 1
fi
echo "RabbitMQ server restarted successfully."

# 添加 RabbitMQ 用户
rabbitmqctl add_user rabbitmq "$RABBIT_PASS"
if [ $? -ne 0 ]; then
    echo "Failed to add rabbitmq user."
    exit 1
fi
echo "RabbitMQ user 'rabbitmq' added successfully."

# 设置 RabbitMQ 用户权限
rabbitmqctl set_permissions rabbitmq ".*" ".*" ".*"
if [ $? -ne 0 ]; then
    echo "Failed to set permissions for rabbitmq user."
    exit 1
fi
echo "Permissions for RabbitMQ user 'rabbitmq' set successfully."

#安装 Memcached 缓存服务

# 安装 Memcached 和 Python-Memcached
yum -y install memcached python-memcached
if [ $? -ne 0 ]; then
    echo "Failed to install memcached and python-memcached."
    exit 1
fi
echo "Memcached and python-memcached installed successfully."


CONFIG_FILE_MEMCACHED="/etc/sysconfig/memcached"
sed -i.bak "s/^OPTIONS=.*/OPTIONS=\"-l 127.0.0.1,::1,$CONTROLLER_INTERNAL_IP\"/" $CONFIG_FILE_MEMCACHED
if [ $? -ne 0 ]; then
    echo "Failed to update memcached configuration."
    exit 1
fi
echo "Memcached configuration updated successfully to listen on $CONTROLLER_INTERNAL_IP."

# 设置 Memcached 服务为开机启动并立即启动
systemctl enable memcached
if [ $? -ne 0 ]; then
    echo "Failed to enable memcached service."
    exit 1
fi
echo "Memcached service enabled to start on boot."

echo "Memcached service restarting..."
systemctl restart memcached
if [ $? -ne 0 ]; then
    echo "Failed to restart memcached service."
    exit 1
fi
echo "Memcached service restarted successfully."

#安装 etcd 分布式键值对服务


#!/bin/bash

# 安装 etcd
echo "Installing etcd..."
yum -y install etcd
if [ $? -ne 0 ]; then
    echo "Failed to install etcd."
    exit 1
fi
echo "etcd installed successfully."

# 配置 etcd
CONFIG_FILE_ETCD="/etc/etcd/etcd.conf"
echo "Configuring etcd..."

# 查找并取消注释和修改相关字段

sed -i "s|#ETCD_LISTEN_PEER_URLS=.*|ETCD_LISTEN_PEER_URLS=\"http://$CONTROLLER_INTERNAL_IP:2380\"|" "$CONFIG_FILE_ETCD"
sed -i "s|#ETCD_LISTEN_CLIENT_URLS=.*|ETCD_LISTEN_CLIENT_URLS=\"http://$CONTROLLER_INTERNAL_IP:2379,http://127.0.0.1:2379\"|" "$CONFIG_FILE_ETCD"
sed -i "s|#ETCD_NAME=.*|ETCD_NAME=\"controller\"|" "$CONFIG_FILE_ETCD"
sed -i "s|#ETCD_INITIAL_ADVERTISE_PEER_URLS=.*|ETCD_INITIAL_ADVERTISE_PEER_URLS=\"http://$CONTROLLER_INTERNAL_IP:2380\"|" "$CONFIG_FILE_ETCD"
sed -i "s|#ETCD_ADVERTISE_CLIENT_URLS=.*|ETCD_ADVERTISE_CLIENT_URLS=\"http://$CONTROLLER_INTERNAL_IP:2379\"|" "$CONFIG_FILE_ETCD"
sed -i "s|#ETCD_INITIAL_CLUSTER=.*|ETCD_INITIAL_CLUSTER=\"controller=http://$CONTROLLER_INTERNAL_IP:2380\"|" "$CONFIG_FILE_ETCD"
sed -i "s|#ETCD_INITIAL_CLUSTER_TOKEN=.*|ETCD_INITIAL_CLUSTER_TOKEN=\"etcd-cluster-01\"|" "$CONFIG_FILE_ETCD"
sed -i "s|#ETCD_INITIAL_CLUSTER_STATE=.*|ETCD_INITIAL_CLUSTER_STATE=\"new\"|" "$CONFIG_FILE_ETCD"

if [ $? -ne 0 ]; then
    echo "Failed to configure etcd."
    exit 1
fi
echo "etcd configured successfully."

# 启动并启用 etcd
echo "Enabling and starting etcd service..."
systemctl enable etcd
if [ $? -ne 0 ]; then
    echo "Failed to enable etcd service."
    exit 1
fi

echo "etcd service restarting...."
systemctl restart etcd
if [ $? -ne 0 ]; then
    echo "Failed to restart etcd service."
    exit 1
fi

echo "etcd service enabled and restarted successfully."

#作者：@Dzzan
#E-mail:d3zzan@gmail.com
