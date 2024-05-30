#!/bin/bash

# 获取 OpenStack 用户 Placement 的密码用于与 Nova 交互
read -s -p "Enter your placement password: " PLACEMENT_PASS
echo

# 设置 OpenStack 用户 Nova 的密码
read -s -p "Set your nova password: " NOVA_PASS
echo

MY_IP="192.168.8.20"
CONFIG_FILE="/etc/nova/nova.conf"
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
transport_url = rabbit://rabbitmq:000000@controller:5672
my_ip = $MY_IP
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver
EOF
)
CONFIG_OPTION_VNC=$(cat <<EOF
enabled = true
server_listen = 0.0.0.0
server_proxyclient_address = $MY_IP
novncproxy_base_url = http://192.168.8.10:6080/vnc_auto.html
EOF
)
CONFIG_OPTION_LIBVIRT="virt_type = qemu"

# 安装 Nova 包
yum -y install openstack-nova-compute
if [ $? -ne 0 ]; then
    echo "Failed to install openstack-nova-compute."
    exit 1
else
    echo "openstack-nova-compute installed successfully."
fi

# 备份并清理 nova.conf 文件
cp /etc/nova/nova.conf /etc/nova/nova.bak
grep -Ev '^$|#' /etc/nova/nova.bak > /etc/nova/nova.conf

# 修改 nova.conf
sed -i "/^\[api\]$/a $CONFIG_OPTION_API" "$CONFIG_FILE"
sed -i "/^\[keystone_authtoken\]$/a $CONFIG_OPTION_KEYSTONE_AUTHTOKEN" "$CONFIG_FILE"
sed -i "/^\[placement\]$/a $CONFIG_OPTION_PLACEMENT" "$CONFIG_FILE"
sed -i "/^\[glance\]$/a $CONFIG_OPTION_GLANCE" "$CONFIG_FILE"
sed -i "/^\[oslo_concurrency\]$/a $CONFIG_OPTION_OSLO_CONCURRENCY" "$CONFIG_FILE"
sed -i "/^\[DEFAULT\]$/a $CONFIG_OPTION_DEFAULT" "$CONFIG_FILE"
sed -i "/^\[vnc\]$/a $CONFIG_OPTION_VNC" "$CONFIG_FILE"
sed -i "/^\[libvirt\]$/a $CONFIG_OPTION_LIBVIRT" "$CONFIG_FILE"

# 启用 Nova 和 libvirtd 服务
systemctl enable libvirtd openstack-nova-compute

# 重启 Nova 和 libvirtd 服务
echo "Nova services restarting..."
systemctl restart libvirtd openstack-nova-compute
if [ $? -ne 0 ]; then
    echo "Failed to restart Nova libvirtd services."
    exit 1
else
    echo "Nova libvirtd restarted successfully."
fi

echo "OpenStack Nova has been installed and configured successfully."


#作者：@Dzzan
#E-mail:d3zzan@gmail.com
