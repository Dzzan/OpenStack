#!/bin/bash

KEYSTOEN_SCRIPT="keystone.sh"
GLANCE_SCRIPT="glance.sh"
PLACEMENT_SCRIPT="placement.sh"
NOVA_FOR_CONTROLLER_SCRIPT="nova_for_controller.sh"
NEUTRON_FOR_CONTEORLLER_SCRIPT="neutron_for_controller.sh"
CINDER_SCRIPT="cinder.sh"

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

