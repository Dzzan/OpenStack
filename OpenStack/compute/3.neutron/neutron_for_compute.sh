#!/bin/bash

# 获取 KeyStone 用户 neutron 密码
read -s -p "Enter your neutron password: " NEUTRON_PASS
echo

# 针对 neutron.conf 的修改
CONFIG_FILE_1="/etc/neutron/neutron.conf"
CONFIG_OPTION_DEFAULT_1=$(cat <<EOF
transport_url = rabbit://rabbitmq:000000@controller:5672
auth_strategy = keystone
EOF
)
CONFIG_OPTION_KEYSTONE_AUTHTOKEN=$(cat <<EOF
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = project
username = neutron
password = $NEUTRON_PASS
EOF
)
CONFIG_OPTION_OSLO_CONCURRENCY="lock_path = /var/lib/neutron/tmp"

# 针对 linuxbridge_agent.ini 的修改
CONFIG_FILE_2="/etc/neutron/plugins/ml2/linuxbridge_agent.ini"
CONFIG_OPTION_DEFAULT_2=$(cat <<EOF
[linux_bridge]
physical_interface_mappings = provider:ens36
EOF
)
CONFIG_OPTION_VXLAN="enable_vxlan = false"
CONFIG_OPTION_SECURITYGROUP=$(cat <<EOF
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
EOF
)

# 针对 nova.conf 的修改
CONFIG_FILE_3="/etc/nova/nova.conf"
CONFIG_OPTION_DEFAULT_3=$(cat <<EOF
vif_plugging_is_fatal = false
vif_plugging_timeout = 0
EOF
)
CONFIG_OPTION_NEUTRON=$(cat <<EOF
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = project
username = neutron
password = $NEUTRON_PASS
EOF
)

# 安装 openstack-neutron-linuxbridge 包
yum -y install openstack-neutron-linuxbridge

# 备份与修改 Neutron 配置文件
cp /etc/neutron/neutron.conf /etc/neutron/neutron.bak
grep -Ev '^$|#' /etc/neutron/neutron.bak > /etc/neutron/neutron.conf

# 修改 neutron.conf
sed -i "/^\[keystone_authtoken\]$/a $CONFIG_OPTION_KEYSTONE_AUTHTOKEN" "$CONFIG_FILE_1"
sed -i "/^\[oslo_concurrency\]$/a $CONFIG_OPTION_OSLO_CONCURRENCY" "$CONFIG_FILE_1"
sed -i "/^\[DEFAULT\]$/a $CONFIG_OPTION_DEFAULT_1" "$CONFIG_FILE_1"

# 修改 linuxbridge_agent.ini
sed -i "/^\[DEFAULT\]$/a $CONFIG_OPTION_DEFAULT_2" "$CONFIG_FILE_2"
sed -i "/^\[vxlan\]$/a $CONFIG_OPTION_VXLAN" "$CONFIG_FILE_2"
sed -i "/^\[securitygroup\]$/a $CONFIG_OPTION_SECURITYGROUP" "$CONFIG_FILE_2"

# 修改 nova.conf
sed -i "/^\[neutron\]$/a $CONFIG_OPTION_NEUTRON" "$CONFIG_FILE_3"
sed -i "/^\[DEFAULT\]$/a $CONFIG_OPTION_DEFAULT_3" "$CONFIG_FILE_3"

# 重启计算节点的 Nova 服务
echo "Nova service restarting..."
systemctl restart openstack-nova-compute
if [ $? -ne 0 ]; then
    echo "Failed to restart Nova services."
    exit 1
else
    echo "Nova services restarted successfully."
fi

# 启用计算节点的 Neutron 网桥代理服务
systemctl enable neutron-linuxbridge-agent

# 重启计算节点的 Neutron 网桥代理服务
echo "Neutron service restarting..."
systemctl restart neutron-linuxbridge-agent
if [ $? -ne 0 ]; then
    echo "Failed to restart Neutron services."
    exit 1
else
    echo "Neutron services restarted successfully."
fi

echo "OpenStack Neutron has been installed and configured successfully."


#作者：@Dzzan
#E-mail：d3zzan@gmail.com
