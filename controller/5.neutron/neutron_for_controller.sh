#!/bin/bash

#获取用户数据库 root 密码
read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
echo

#获取 KeyStone 用户 Nova 密码用于和Neutron交互
read -s -p "Enter your nova password: " NOVA_PASS
echo

#设置数据库 neutron 密码
read -s -p "Set your db_neutron password: " NEUTRON_DBPASS
echo

#设置 KeyStone 用户 neutron 密码
read -s -p "Set your neutron password: " NEUTRON_PASS
echo

# 修改网卡配置
ifconfig ens36 promisc

# 增加配置
if ! grep -Fxq "ifconfig ens36 promisc" /etc/profile; then
   echo "ifconfig ens36 promisc" >> /etc/profile
   echo "Configuration added to /etc/profile."
else
   echo "Configuration already exists in /etc/profile."
fi

if ! grep -Fxq "net.bridge.bridge-nf-call-iptables = 1" /etc/sysctl.conf; then
   echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
   echo "Configuration_1 added to /etc/sysctl.conf."
else
   echo "Configuration_1 already exists in /etc/sysctl.conf."
fi

if ! grep -Fxq "net.bridge.bridge-nf-call-ip6tables = 1" /etc/sysctl.conf; then
   echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.conf
   echo "Configuration_2 added to /etc/sysctl.conf."
else
   echo "Configuration_2 already exists in /etc/sysctl.conf."
fi

# 加载 br_netfilter 模块
modprobe br_netfilter

# 使配置生效
sysctl -p

# 设置 Neutron 配置
MY_IP="192.168.8.10"
CONFIG_FILE_1="/etc/neutron/neutron.conf"
CONFIG_OPTION_DATABASE="connection = mysql+pymysql://neutron:$NEUTRON_DBPASS@controller/neutron"
CONFIG_OPTION_DEFAULT_1=$(cat <<EOF
auth_strategy = keystone
core_plugin = ml2
service_plugins =
transport_url = rabbit://rabbitmq:000000@controller
auth_strategy = keystone
notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true
EOF
)
CONFIG_OPTION_KEYSTONE_AUTHTOKEN=$(cat <<EOF
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = project
username = neutron
password = $NEUTRON_PASS
EOF
)
CONFIG_OPTION_OSLO_CONCURRENCY="lock_path = /var/lib/nova/tmp"
CONFIG_OPTION_NOVA=$(cat <<EOF
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = project
username = nova
password = $NOVA_PASS
region_name = RegionOne
server_proxyclient_address = $MY_IP
EOF
)

# 设置 Linux Bridge 配置
CONFIG_FILE_2="/etc/neutron/plugins/ml2/linuxbridge_agent.ini"
CONFIG_OPTION_LINUX_BRIDGE="physical_interface_mappings = provider:ens34"
CONFIG_OPTION_VXLAN="enable_vxlan = false"
CONFIG_OPTION_SECURITYGROUP=$(cat <<EOF
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
EOF
)

# 设置 DHCP Agent 配置
CONFIG_FILE_3="/etc/neutron/dhcp_agent.ini"
CONFIG_OPTION_DEFAULT_3=$(cat <<EOF
interface_driver = linuxbridge
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = true 
EOF
)

# 设置 Metadata Agent 配置
CONFIG_FILE_4="/etc/neutron/metadata_agent.ini"
CONFIG_OPTION_DEFAULT_4=$(cat <<EOF
nova_metadata_host = controller
metadata_proxy_shared_secret = METADATA_SECRET
EOF
)

# 设置 Nova 配置
CONFIG_FILE_5="/etc/nova/nova.conf"
CONFIG_OPTION_NEUTRON=$(cat <<EOF
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = project
username = neutron
password = $NEUTRON_PASS
service_metadata_proxy = true
metadata_proxy_shared_secret = METADATA_SECRET
EOF
)
CONFIG_OPTION_DEFAULT_5=$(cat <<EOF
enabled_apis = osapi_compute,metadata           
transport_url = rabbit://rabbitmq:000000@controller:5672
my_ip = $MY_IP
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver
EOF
)
CONFIG_OPTION_VNC=$(cat <<EOF
enabled = true
server_listen = $MY_IP
server_proxyclient_address = $MY_IP
EOF
)

# 安装必要的 Neutron 包
yum -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge
if [ $? -ne 0 ]; then
    echo "Failed to install OpenStack Neutron packages."
    exit 1
else
    echo "OpenStack Neutron packages installed successfully."
fi

# 删除现有的 Neutron 数据库
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS neutron;"
if [ $? -ne 0 ]; then
    echo "Failed to delete existing Neutron databases."
    exit 1
else
    echo "Existing Neutron databases deleted."
fi

# 创建新的数据库和用户
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<MYSQL_SCRIPT
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';
MYSQL_SCRIPT

if [ $? -ne 0 ]; then
    echo "Failed to perform database operations."
    exit 1
else
    echo "Database operations completed successfully."
fi

# 备份和修改 neutron.conf 配置文件
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
grep -Ev '^$|#' /etc/neutron/neutron.conf.bak > /etc/neutron/neutron.conf

# 修改 neutron.conf
sed -i "/^\[database\]$/a $CONFIG_OPTION_DATABASE" "$CONFIG_FILE_1"
sed -i "/^\[nova\]$/a $CONFIG_OPTION_NOVA" "$CONFIG_FILE_1"
sed -i "/^\[keystone_authtoken\]$/a $CONFIG_OPTION_KEYSTONE_AUTHTOKEN" "$CONFIG_FILE_1"
sed -i "/^\[oslo_concurrency\]$/a $CONFIG_OPTION_OSLO_CONCURRENCY" "$CONFIG_FILE_1"
sed -i "/^\[DEFAULT\]$/a $CONFIG_OPTION_DEFAULT_1" "$CONFIG_FILE_1"

# 启用 ML2 插件
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

# 备份和修改 ML2 插件配置文件
cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.bak
grep -Ev '^$|#' /etc/neutron/plugins/ml2/ml2_conf.bak > /etc/neutron/plugins/ml2/ml2_conf.ini

# 修改 linuxbridge_agent.ini
sed -i "/^\[linux_bridge\]$/a $CONFIG_OPTION_LINUX_BRIDGE" "$CONFIG_FILE_2"
sed -i "/^\[vxlan\]$/a $CONFIG_OPTION_VXLAN" "$CONFIG_FILE_2"
sed -i "/^\[securitygroup\]$/a $CONFIG_OPTION_SECURITYGROUP" "$CONFIG_FILE_2"

# 备份和修改 DHCP 代理配置文件
cp /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.bak
grep -Ev '^$|#' /etc/neutron/dhcp_agent.bak > /etc/neutron/dhcp_agent.ini

# 修改 dhcp_agent.ini
sed -i "/^\[DEFAULT\]$/a $CONFIG_OPTION_DEFAULT_3" "$CONFIG_FILE_3"

# 修改 metadata_agent.ini
sed -i "/^\[DEFAULT\]$/a $CONFIG_OPTION_DEFAULT_4" "$CONFIG_FILE_4"

# 修改 nova.conf
sed -i "/^\[neutron\]$/a $CONFIG_OPTION_NEUTRON" "$CONFIG_FILE_5"
sed -i "/^\[DEFAULT\]$/a $CONFIG_OPTION_DEFAULT_5" "$CONFIG_FILE_5"
sed -i "/^\[vnc\]$/a $CONFIG_OPTION_VNC" "$CONFIG_FILE_5"

# 初始化 Neutron 的数据库
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade heads" neutron

source admin-login
openstack user create --domain default --password $NEUTRON_PASS neutron
if [ $? -ne 0 ]; then
    echo "Failed to create neutron user."
    exit 1
fi
echo "Neutron user created successfully."

openstack role add --project project --user neutron admin
if [ $? -ne 0 ]; then
    echo "Failed to add role to neutron user."
    exit 1 
fi  
echo "Role added to neutron user successfully."

openstack service create --name neutron network
if [ $? -ne 0 ]; then
    echo "Failed to create neutron service."
    exit 1
fi
echo "Neutron service created successfully."

openstack endpoint create --region RegionOne neutron public http://controller:9696
if [ $? -ne 0 ]; then
    echo "Failed to create public endpoint for neutron."
    exit 1
fi
echo "Public endpoint for neutron created successfully."

openstack endpoint create --region RegionOne neutron internal http://controller:9696
if [ $? -ne 0 ]; then
    echo "Failed to create internal endpoint for neutron."
    exit 1
fi
echo "Internal endpoint for neutron created successfully."

openstack endpoint create --region RegionOne neutron admin http://controller:9696
if [ $? -ne 0 ]; then
    echo "Failed to create admin endpoint for neutron."
    exit 1
fi       
echo "Admin endpoint for neutron created successfully."

# 重启 Nova 服务
echo "Nova service restarting..."
systemctl restart openstack-nova-api
if [ $? -ne 0 ]; then 
    echo "Failed to restart Nova services."
    exit 1
else
    echo "Nova services restarted successfully."
fi

# 启用 Neutron 服务
systemctl enable neutron-server neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent

# 重启 Neutron 服务
echo "Neutron service restarting..."
systemctl restart neutron-server neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent
if [ $? -ne 0 ]; then 
    echo "Failed to restart Neutron services."
    exit 1
else
    echo "Neutron services restarted successfully."
fi

echo "OpenStack Neutron has been installed and configured successfully."

#作者：@Dzzan
#E-mail：d3zzan@gmail.com
