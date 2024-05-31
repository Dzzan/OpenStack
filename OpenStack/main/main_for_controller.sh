#!/bin/bash

KEYSTOEN_SCRIPT="\OpenStack\controller\1.keystone\keystone.sh"
GLANCE_SCRIPT="\OpenStack\controller\2.glance\glance.sh"
PLACEMENT_SCRIPT="\OpenStack\controller\3.placement\placement.sh"
NOVA_FOR_CONTROLLER_SCRIPT="\OpenStack\controller\4.nova\nova_for_controller.sh"
NEUTRON_FOR_CONTEORLLER_SCRIPT="\OpenStack\controller\5.neutron\neutron_for_controller.sh"
CINDER_SCRIPT="\OpenStack\controller\6.cinder\cinder.sh"

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

echo "Running Placement setup..."
bash $NOVA_FOR_CONTROLLER_SCRIPT
if [ $? -ne 0 ]; then
    echo "Nova setup falied."
    exit 1
fi
echo "Nova setup completed successfully."

echo "Running Placement setup..."
bash $NEUTRON_FOR_CONTEORLLER_SCRIPT
if [ $? -ne 0 ]; then
    echo "Neutron setup falied."
    exit 1
fi
echo "Neutron setup completed successfully."

echo "Running Placement setup..."
bash $CINDER_SCRIPT
if [ $? -ne 0 ]; then
    echo "Cinder setup falied."
    exit 1
fi
echo "Cinder setup completed successfully."

