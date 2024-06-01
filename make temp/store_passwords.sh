#!/bin/bash

# 获取 MySQL root 密码
read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
echo

# 设置数据库和用户密码
read -s -p "Set your db_keystone password: " KEYSTONE_DBPASS
echo
read -s -p "Set your db_glance password: " GLANCE_DBPASS
echo
read -s -p "Set your db_placement password: " PLACEMENT_DBPASS
echo
read -s -p "Set your db_nova_api password: " NOVA_API_DBPASS
echo
read -s -p "Set your db_nova_cell0 password: " NOVA_CELL0_DBPASS
echo
read -s -p "Set your db_nova password: " NOVA_DBPASS
echo
read -s -p "Set your db_neutron password: " NEUTRON_DBPASS
echo
read -s -p "Set your db_cinder password: " CINDER_DBPASS
echo

# 设置 KeyStone 管理员密码
read -s -p "Set your keystone admin password: " ADMIN_PASSWORD
echo

# 设置 KeyStone 用户密码
read -s -p "Set your glance password: " GLANCE_PASS
echo
read -s -p "Set your placement password: " PLACEMENT_PASS
echo
read -s -p "Set your nova password: " NOVA_PASS
echo
read -s -p "Set your neutron password: " NEUTRON_PASS
echo
read -s -p "Set your cinder password: " CINDER_PASS
echo



# 创建临时文件来存储密码
TEMP_FILE_SQL="/tmp/openstack_needed_passwords_1"
cat > "$TEMP_FILE_SQL" <<EOF
export MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
export GLANCE_DBPASS=$GLANCE_DBPASS
export PLACEMENT_DBPASS=$PLACEMENT_DBPASS
export NOVA_API_DBPASS=$NOVA_API_DBPASS
export NOVA_CELL0_DBPASS=$NOVA_CELL0_DBPASS
export NOVA_DBPASS=$NOVA_DBPASS
export NEUTRON_DBPASS=$NEUTRON_DBPASS
export CINDER_DBPASS=$CINDER_DBPASS
EOF

TEMP_FILE_KEYSTONE="/tmp/openstack_needed_passwords_2"
cat > "$TEMP_FILE_KEYSTONE" <<EOF
export ADMIN_PASSWORD=$ADMIN_PASSWORD
export GLANCE_PASS=$GLANCE_PASS
export PLACEMENT_PASS=$PLACEMENT_PASS
export NOVA_PASS=$NOVA_PASS
export NEUTRON_PASS=$NEUTRON_PASS
export CINDER_PASS=$CINDER_PASS
EOF


# 确保只有当前用户可以访问临时文件
chmod 600 "$TEMP_FILE_SQL"
chmod 600 "$TEMP_FILE_KEYSTONE"

echo "Passwords have been stored in $TEMP_FILE_SQL and $TEMP_FILE_KEYSTONE"

