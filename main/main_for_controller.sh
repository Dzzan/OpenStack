#!/bin/bash

source /root/admin-login

chmod +x /root/OpenStack/controller/1.keystone/keystone.sh
chmod +x /root/OpenStack/controller/2.glance/glance.sh
chmod +x /root/OpenStack/controller/3.placement/placement.sh
chmod +x /root/OpenStack/controller/4.nova/nova_for_controller.sh
chmod +x /root/OpenStack/controller/5.neutron/neutron_for_controller.sh
chmod +x /root/OpenStack/controller/6.cinder/cinder.sh
chmod +x /root/OpenStack/make_temp/store_passwords.sh
chmod +x /root/OpenStack/make_temp/your_ip.sh

YOUR_IP_SCRIPT="/root/OpenStack/make_temp/your_ip.sh"
STORE_PASSWDS_SCRIPT="/root/OpenStack/make_temp/store_passwords.sh"
KEYSTONE_SCRIPT="/root/OpenStack/controller/1.keystone/keystone.sh"
GLANCE_SCRIPT="/root/OpenStack/controller/2.glance/glance.sh"
PLACEMENT_SCRIPT="/root/OpenStack/controller/3.placement/placement.sh"
NOVA_FOR_CONTROLLER_SCRIPT="/root/OpenStack/controller/4.nova/nova_for_controller.sh"
NEUTRON_FOR_CONTROLLER_SCRIPT="/root/OpenStack/controller/5.neutron/neutron_for_controller.sh"
CINDER_SCRIPT="/root/OpenStack/controller/6.cinder/cinder.sh"

echo "Get your IP..."
bash $YOUR_IP_SCRIPT
if [ $? -ne 0 ]; then
    echo "Store your IP failed."
    exit 1
fi
echo "Store your IP completed successfully."


echo "Get your passwords..."
bash $STORE_PASSWDS_SCRIPT
if [ $? -ne 0 ]; then
    echo "Store your passwords failed."
    exit 1
fi
echo "Store your passwords completed successfully."

echo "Running Keystone setup..."
bash $KEYSTONE_SCRIPT
if [ $? -ne 0 ]; then
    echo "Keystone setup failed."
    exit 1
fi
echo "Keystone setup completed successfully."

echo "Running Glance setup..."
bash $GLANCE_SCRIPT
if [ $? -ne 0 ]; then
    echo "Glance setup falied."
    exit 1
fi
echo "Glance setup completed successfully."

echo "Running Placement setup..."
bash $PLACEMENT_SCRIPT
if [ $? -ne 0 ]; then
    echo "Placement setup falied."
    exit 1
fi
echo "Placement setup completed successfully."

echo "Running Nova setup..."
bash $NOVA_FOR_CONTROLLER_SCRIPT
if [ $? -ne 0 ]; then
    echo "Nova setup falied."
    exit 1
fi
echo "Nova setup completed successfully."

echo "Running Neutron setup..."
bash $NEUTRON_FOR_CONTROLLER_SCRIPT
if [ $? -ne 0 ]; then
    echo "Neutron setup falied."
    exit 1
fi
echo "Neutron setup completed successfully."

echo "Running Cinder setup..."
bash $CINDER_SCRIPT
if [ $? -ne 0 ]; then
    echo "Cinder setup falied."
    exit 1
fi
echo "Cinder setup completed successfully."

echo "OpenStack has been installed and configured successfully."

#作者：@Dzzan
#E-mail：d3zzan@gmail.com
