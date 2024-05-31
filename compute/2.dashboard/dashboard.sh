#!/bin/bash

# 安装 OpenStack Dashboard
yum -y install openstack-dashboard
if [ $? -ne 0 ]; then
    echo "Failed to install openstack-dashboard."
    exit 1
else
    echo "openstack-dashboard installed successfully."
fi

# 配置 /etc/openstack-dashboard/local_settings
CONFIG_FILE="/etc/openstack-dashboard/local_settings"

# 备份配置文件
cp $CONFIG_FILE ${CONFIG_FILE}.bak

# 设置允许所有主机访问
sed -i "s/ALLOWED_HOSTS = .*/ALLOWED_HOSTS = ['*']/" $CONFIG_FILE

# 设置控制节点的位置
sed -i "s/OPENSTACK_HOST = .*/OPENSTACK_HOST = 'controller'/" $CONFIG_FILE

# 设置时区
sed -i "s/TIME_ZONE = .*/TIME_ZONE = 'Asia\/Shanghai'/" $CONFIG_FILE

# 配置缓存服务
sed -i "s/#SESSION_ENGINE = 'django.contrib.sessions.backends.cache'/SESSION_ENGINE = 'django.contrib.sessions.backends.cache'/" $CONFIG_FILE

sed -i "/^SESSION_ENGINE = .*/a CACHES = {\
'default': {\
'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',\
'LOCATION': 'controller:11211',\
}\
}" $CONFIG_FILE

# 启用多域支持
if ! grep -q "OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True" $CONFIG_FILE; then
    echo "OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True" >> $CONFIG_FILE
fi

# 指定 OpenStack 组件的版本
if ! grep -q "OPENSTACK_API_VERSIONS = {" $CONFIG_FILE; then
    cat <<EOF >> $CONFIG_FILE
OPENSTACK_API_VERSIONS = {
"identity": 3,
"image": 2,
"volume": 3,
}
EOF
fi

# 设置默认域
if ! grep -q "OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'Default'" $CONFIG_FILE; then
    echo "OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'Default'" >> $CONFIG_FILE
fi

# 设置默认角色
if ! grep -q "OPENSTACK_KEYSTONE_DEFAULT_ROLE = 'user'" $CONFIG_FILE; then
    echo "OPENSTACK_KEYSTONE_DEFAULT_ROLE = 'user'" >> $CONFIG_FILE
fi

# 配置 Neutron 网络
if ! grep -q "OPENSTACK_NEUTRON_NETWORK = {" $CONFIG_FILE; then
    cat <<EOF >> $CONFIG_FILE
OPENSTACK_NEUTRON_NETWORK = {
'enable_auto_allocated_network': False,
'enable_distributed_router': False,
'enable_fip_topology_check': False,
'enable_ha_router': False,
'enable_ipv6': False,
'enable_quotas': False,
'enable_rbac_policy': False,
'enable_router': False,
}
EOF
fi

# 进入 Dashboard 网站目录
cd /usr/share/openstack-dashboard || { echo "Failed to change directory to /usr/share/openstack-dashboard"; exit 1; }

# 生成 Dashboard 的 Web 服务配置文件
python manage.py make_web_conf --apache > /etc/httpd/conf.d/openstack-dashboard.conf
if [ $? -ne 0 ]; then
    echo "Failed to generate openstack-dashboard.conf."
    exit 1
else
    echo "openstack-dashboard.conf generated successfully."
fi

# 创建策略文件的软连接
ln -s /etc/openstack-dashboard/* /usr/share/openstack-dashboard/openstack_dashboard/conf/

# 启动 httpd 服务

# 启动和启用 httpd 服务
systemctl enable httpd
if [ $? -ne 0 ]; then
    echo "Failed to enable httpd service."
    exit 1
else
    echo "httpd service enabled successfully."
fi

echo "OpenStack Dashboard has been installed and configured successfully."

# 重启 httpd 服务
echo "Httpd service restarting..."
systemctl restart httpd
if [ $? -ne 0 ]; then
    echo "Failed to restart httpd service."
    exit 1
else
    echo "httpd service restarted successfully."
fi

echo "OpenStack Dashboard has been installed and configured successfully."

#作者：@Dzzan
#E-mail：d3zzan@gmail.com
