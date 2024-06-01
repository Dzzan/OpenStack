#!/bin/bash

# 获取 控制节点 ip 内网
read  -p "Enter the ip of controller(internal): " IP_CONTROLLER_INTERNAL
echo

# 获取 控制节点 ip 外网
read  -p "Enter the ip of controller(public): " IP_CONTROLLER_PUBLIC
echo

# 获取 计算节点 ip 内网
read  -p "Enter the ip of compute(internal): " IP_COMPUTE_INTERNAL
echo

# 获取 计算节点 ip 内网
read  -p "Enter the ip of compute(public): " IP_COMPUTE_PUBLIC
echo


TEMP_FILE_IP="/tmp/ip"
cat > "$TEMP_FILE_IP" <<EOF
export IP_CONTROLLER_INTERNAL=$IP_CONTROLLER_INTERNAL
export IP_CONTROLLER_PUBLIC=$IP_CONTROLLER_PUBLIC
export IP_COMPUTE_INTERNAL=$IP_COMPUTE_INTERNAL
export IP_COMPUTE_PUBLIC=$IP_COMPUTE_PUBLIC
EOF

chmod 600 "$TEMP_FILE_IP"

echo "Ip info has been stored in $TEMP_FILE_IP"

