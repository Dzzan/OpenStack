#!/bin/bash

yum install -y openstack-keystone httpd mod_wsgi

if [ $? -eq 0 ]; then
    echo "Package openstack-keystone installed successfully."

    mysql -uroot -p000000 -e "DROP DATABASE IF EXISTS keystone;"
    if [ $? -eq 0 ]; then
        echo "Existing keystone database deleted."

   	 mysql -uroot -p000000 -e "CREATE DATABASE keystone; GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '000000'; GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '000000';"

    if [ $? -eq 0 ]; then
        echo "Database operations completed successfully."

        su keystone -s /bin/sh -c "keystone-manage db_sync"

        CONFIG_OPTION_DATABASE="connection = mysql+pymysql://keystone:000000@controller/keystone"
        CONFIG_OPTION_TOKEN="provider = fernet"
        CONFIG_FILE="/etc/keystone/keystone.conf"

        su - root -c "
if grep -q '^connection = mysql+pymysql://keystone:000000@controller/keystone' \"$CONFIG_FILE\"; then
    echo 'The database configuration already exists.'
else
    sed -i '/^\[database\]$/a $CONFIG_OPTION_DATABASE' \"$CONFIG_FILE\"
    echo 'Database connection configuration added successfully.'
fi

if grep -q '^provider = fernet' \"$CONFIG_FILE\"; then
    echo 'The token configuration already exists.'
else
    sed -i '/^\[token\]$/a $CONFIG_OPTION_TOKEN' \"$CONFIG_FILE\"
    echo 'Token configuration added successfully.'
fi

if [ \$? -eq 0 ]; then
    echo 'Configuration added to $CONFIG_FILE.'
    keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
    if [ \$? -eq 0 ]; then
        echo 'Fernet initialization finished.'
        keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
        if [ \$? -eq 0 ]; then
            echo 'Credential setup finished.'
            keystone-manage bootstrap --bootstrap-password 000000 --bootstrap-admin-url http://controller:5000/v3 --bootstrap-internal-url http://controller:5000/v3 --bootstrap-public-url http://controller:5000/v3 --bootstrap-region-id RegionOne
            if [ \$? -eq 0 ]; then
                echo 'User initialization finished.'
                
                if [ -e /etc/httpd/conf.d/wsgi-keystone.conf ]; then
                    rm /etc/httpd/conf.d/wsgi-keystone.conf
                    echo 'Existing /etc/httpd/conf.d/wsgi-keystone.conf removed.'
                fi
                ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
                echo 'Symlink /etc/httpd/conf.d/wsgi-keystone.conf created.'

                sed -i 's/^#ServerName.*/ServerName controller/' /etc/httpd/conf/httpd.conf
                if [ \$? -eq 0 ]; then
                    echo 'Write successfully.'
                    systemctl enable httpd
                    systemctl start httpd
                    cat << EOF >> /root/admin-login
export OS_USERNAME=admin
export OS_PASSWORD=000000
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
                    echo 'Admin login script created successfully.'
                fi
            fi
        fi
    fi
fi
"
   		 else
        		echo "Failed to perform database operations."
   		 fi
	else
        	echo "Failed to delete existing keystone database."
    	fi
else
    echo "Failed to install package openstack-keystone."
fi

#作者：@CZR
#联系方式：1573799514@qq.com
