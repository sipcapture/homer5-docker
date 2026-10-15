#!/bin/bash
# ----------------------------------------------------
# HOMER 5 Docker (http://sipcapture.org)
# ----------------------------------------------------
# -- Bootstrap script for Homer's database
# ----------------------------------------------------

if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
  ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
  echo "${TZ}" >/etc/timezone
  export TZ
fi

if [ "${USE_REMOTE_MYSQL:-false}" = true ] && [ "${DB_HOST:-mysql}" = "mysql" ]; then
  echo "USE_REMOTE_MYSQL=true but DB_HOST is still 'mysql'. Set DB_HOST to your external MySQL host in homer.env."
  exit 1
fi
# Reads from environment variables to set:
# MYSQL_ROOT_PASSWORD MySQL root password.
# DB_PASS             MySQL password (homer_password)
# DB_USER             MySQL user (homer_user)
# DB_HOST             MySQL host (127.0.0.1 [docker0 bridge])
# KAMAILIO_HEP_PORT   Kamailio HEP Socket port (9060)
# ----------------------------------------------------

# For reference...
# Previously for: MySQL Reconfiguring defaults
#
# PATH_MYSQL_CONFIG=/etc/mysql/my.cnf
# perl -p -i -e "s/sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES/sql_mode=NO_ENGINE_SUBSTITUTION/" $PATH_MYSQL_CONFIG
# sed '/\[mysqld\]/a max_connections = 1024\' -i $PATH_MYSQL_CONFIG

# MYSQL SETUP
SQL_LOCATION=/homer-api/sql/mysql
DATADIR=/var/lib/mysql

# ------- First thing we'll do is wait until mysql is up....

echo "Checking if mysql is alive..."
export MYSQL_PWD=$MYSQL_ROOT_PASSWORD

mysql_started=false
waited=0
while [ "$mysql_started" = false ]; do
  mysqladmin -h $DB_HOST -u root status &> /mysql.status
  if [[ "$(cat /mysql.status)" =~ "Uptime" ]]; then
    echo "Mysql is now running."
    mysql_started=true
  else
    echo "Bootstrap container is waiting for mysql, sleeping 2 seconds, intentionally waited $waited seconds so far"
    waited=$[$waited+2]
    sleep 2
  fi
done

# ------ Now that we have mysql alive, check if the homer tables are already created...

# Show the databases.
databases=$(mysql -h $DB_HOST -u root -s -e 'show databases;')

# Check if the homer_data database is in there.
if [[ ! "$databases" =~ "homer_data" ]]; then

  # If it's not, go ahead and start loading data.
  echo "Beginning initial data load...."

  echo "Creating Databases..."
  mysql --host "$DB_HOST" -u "root" < $SQL_LOCATION/homer_databases.sql
  mysql --host "$DB_HOST" -u "root" < $SQL_LOCATION/homer_user.sql
  mysql --host "$DB_HOST" -u "root" -e "GRANT ALL ON *.* TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS'; FLUSH PRIVILEGES;";
  
  export MYSQL_PWD=$DB_PASS

  echo "Creating Tables..."
  mysql --host "$DB_HOST" -u "$DB_USER" homer_data < $SQL_LOCATION/schema_data.sql
  mysql --host "$DB_HOST" -u "$DB_USER" homer_configuration < $SQL_LOCATION/schema_configuration.sql
  mysql --host "$DB_HOST" -u "$DB_USER" homer_statistic < $SQL_LOCATION/schema_statistic.sql
  
  # echo "Creating local DB Node..."
  mysql --host "$DB_HOST" -u "$DB_USER" homer_configuration -e "REPLACE INTO node VALUES(1,'mysql','homer_data','3306','"$DB_USER"','"$DB_PASS"','sip_capture','node1', 1);"

  echo "Homer initial data load complete" > $DATADIR/.homer_initialized
else
  echo "Detected Homer databases are already installed."
fi

echo "Bootstrapped @ $(date)" > /homer-semaphore/.bootstrapped
echo "Data bootstrapped semaphore written to /homer-semaphore/.bootstrapped"
