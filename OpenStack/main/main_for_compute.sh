#!/bin/bash

NOVA_FOR_COMPUTE_SCRIPT="\OpenStack\compute\1.nova\nova_for_compute.sh"
DASHBOARD_SCRIPT="\OpenStack\compute\2.dashboard\dashboard.sh"
NEUTRON_FOR_COMPUTE_SCRIPT="\OpenStack\compute\3.neutron\neutron_for_compute.sh"

echo "Running Nova setup..."
bash $NOVA_FOR_COMPUTE_SCRIPT
if [ $? -ne 0 ]; then
    echo "Nova setup failed."
    exit 1
fi
echo "Nova setup completed successfully."

echo "Running Dashboard setup..."
bash $DASHBOARD_SCRIPT
if [ $? -ne 0 ]; then
    echo "Dashboard setup falied."
    exit 1
fi
echo "Glance setup completed successfully."

echo "Running Neutron setup..."
bash $NEUTRON_FOR_COMPUTE_SCRIPT
if [ $? -ne 0 ]; then
    echo "Neutron setup falied."
    exit 1
fi
echo "Neutron setup completed successfully."

