#!/bin/bash
# HOMER 5 Docker (http://sipcapture.org)

if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
  ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
  echo "${TZ}" >/etc/timezone
  export TZ
fi
# ----------------------------------------------------
# -- Run script for Homer's Web application
# ----------------------------------------------------
# Reads from environment variables to set:
# DB_PASS             MySQL password (homer_password)
# DB_USER             MySQL user (homer_user)
# DB_HOST             MySQL host (127.0.0.1 [docker0 bridge])
# KAMAILIO_HEP_PORT   Kamailio HEP Socket port (9060)
# ----------------------------------------------------

# Wait for MySQL

while [[ ! -f "/homer-semaphore/.bootstrapped" ]]; do
  echo "Homer web app, waiting for MySQL"
  sleep 2;
done

echo "Homer web app container detected MySQL is running & bootstrapped"


# HOMER API CONFIG
PATH_HOMER_CONFIG=/var/www/html/api/configuration.php
chmod 775 $PATH_HOMER_CONFIG

# Replace values in template
perl -p -i -e "s/\{\{ DB_PASS \}\}/$DB_PASS/" $PATH_HOMER_CONFIG
perl -p -i -e "s/\{\{ DB_HOST \}\}/$DB_HOST/" $PATH_HOMER_CONFIG
perl -p -i -e "s/\{\{ DB_USER \}\}/$DB_USER/" $PATH_HOMER_CONFIG

# Set Permissions for webapp
mkdir /var/www/html/api/tmp
chmod -R 0777 /var/www/html/api/tmp/
chown -R www-data:www-data /var/www/html/store/dashboard
chmod -R 0775 /var/www/html/store/dashboard*

#enable apache mod_php and mod_rewrite
a2enmod php5
a2enmod rewrite

# Apache gets grumpy about PID files pre-existing
rm -f /var/run/apache2/apache2.pid

# Start Apache
apachectl -DFOREGROUND
# apachectl start
