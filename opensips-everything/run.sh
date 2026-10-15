#!/bin/bash
# HOMER 5 Docker OpenSIPS (http://sipcapture.org)
# run.sh {parameters}

# HOMER Options, defaults
DB_USER=homer_user
DB_PASS=homer_password
DB_HOST="127.0.0.1"
DEFAULT_ES_URL="http://localhost:9200"
LISTEN_PORT=${LISTEN_PORT:-9060}

# HOMER MySQL Options, defaults
sqluser=root
sqlpassword=secret

# Container
DOCK_IP="127.0.0.1"
ES_STATUS=disabled

# MYSQL SETUP
SQL_LOCATION=/homer-api/sql/mysql
DATADIR=/var/lib/mysql

show_help() {
cat << EOF
Usage: ${0##*/} [--hep 9060]
Homer5 Docker parameters:

    --dbpass -p             MySQL password (homer_password)
    --dbuser -u             MySQL user (homer_user)
    --dbhost -h             MySQL host (127.0.0.1 [docker0 bridge])
    --mypass -P             MySQL root local password (secret)
    --es     -E             Enable ElasticSearch statistics storage (disabled)
    --es-url -U             ElasticSearch URL ($DEFAULT_ES_URL)
    --hep    -H             OpenSIPS HEP Socket port ($LISTEN_PORT)

EOF
exit 0;
}

# Set container parameters
while true; do
  case "$1" in
    -p | --dbpass )
      if [ "$2" == "" ]; then show_help; fi;
      DB_PASS=$2;
      echo "DB_PASS set to: $DB_PASS";
      shift 2 ;;
    -P | --mypass )
      if [ "$2" == "" ]; then show_help; fi;
      sqlpassword=$2;
      echo "MySQL Pass set to: $sqlpassword";
      shift 2 ;;
    -h | --dbhost )
      if [ "$2" == "" ]; then show_help; fi;
      DB_HOST=$2;
      echo "DB_HOST set to: $DB_HOST";
      shift 2 ;;
    -u | --dbuser )
      if [ "$2" == "" ]; then show_help; fi;
      DB_USER=$2;
      echo "DB_USER set to: $DB_USER";
      shift 2 ;;
    -H | --hep )
      if [ "$2" == "" ]; then show_help; fi;
      LISTEN_PORT=$2;
      echo "HEP Port set to: $LISTEN_PORT";
      shift 2 ;;
    -E | --es )
      ES_STATUS=enabled
      echo "ElasticSearch Enabled";
      shift ;;
    -U | --es-url )
      if [ "$2" == "" ]; then show_help; fi;
      ES_URL=$2;
      echo "ElasticSearch URL set to: $ES_URL";
      shift 2 ;;
    --help )
      show_help;
      exit 0 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ -n "$ES_URL" ]; then
    ES_STATUS=enabled
    echo "INFO: ElasticSearch Enabled by setting URL"
elif [ "$ES_STATUS" = "enabled" ]; then
    ES_URL=$DEFAULT_ES_URL
    echo "INFO: Using default ElasticSearch URL: $ES_URL"
fi

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
chmod -R 0775 /var/www/html/store/dashboard*

#MySQL Reconfig defaults
PATH_MYSQL_CONFIG=/etc/mysql/my.cnf
perl -p -i -e "s/sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES/sql_mode=NO_ENGINE_SUBSTITUTION/" $PATH_MYSQL_CONFIG
sed '/\[mysqld\]/a max_connections = 1024\' -i $PATH_MYSQL_CONFIG

# Handy-dandy MySQL run function
function MYSQL_RUN () {

  chown -R mysql:mysql "$DATADIR"

  echo 'Starting mysqld'
  service mysql start
  echo 'Waiting for mysqld to come online'
  while [ ! -x /var/run/mysqld/mysqld.sock ]; do
      sleep 1
  done

}

# MySQL data loading function
function MYSQL_INITIAL_DATA_LOAD () {

  echo "Beginning initial data load...."

  chown -R mysql:mysql "$DATADIR"
  mysqld --initialize-insecure=on --user=mysql --datadir="$DATADIR"

  MYSQL_RUN

  echo 'Setting root password....'
  mysql -u root -e "SET PASSWORD = PASSWORD('$sqlpassword');FLUSH PRIVILEGES;"

  echo "Creating DB User..."
  mysql  -u "$sqluser" -p"$sqlpassword" -e "CREATE USER '$DB_USER'@'$DB_HOST' IDENTIFIED BY '$DB_PASS';";
  mysql  -u "$sqluser" -p"$sqlpassword" -e "GRANT ALL ON *.* TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS'; FLUSH PRIVILEGES;";

  echo "Creating Databases..."
  mysql  -u "$sqluser" -p"$sqlpassword" < $SQL_LOCATION/homer_databases.sql
  mysql  -u "$sqluser" -p"$sqlpassword" < $SQL_LOCATION/homer_user.sql

  echo "Creating Tables..."
  mysql  -u "$sqluser" -p"$sqlpassword" homer_data < $SQL_LOCATION/schema_data.sql
  mysql  -u "$sqluser" -p"$sqlpassword" homer_configuration < $SQL_LOCATION/schema_configuration.sql
  mysql  -u "$sqluser" -p"$sqlpassword" homer_statistic < $SQL_LOCATION/schema_statistic.sql

  # echo "Creating local DB Node..."
  mysql  -u "$sqluser" -p"$sqlpassword" homer_configuration -e "INSERT INTO node VALUES(1,'mysql','homer_data','3306','"$DB_USER"','"$DB_PASS"','sip_capture','node1', 1);"

  echo "Homer initial data load complete" > $DATADIR/.homer_initialized


}

# This is our handler to determine if we're running mysql internal to this container
# We also bootstrap the data by initially loading it if it's not there.

if [ "$DB_HOST" == "$DOCK_IP" ]; then

    # If we're running an internal container, we want to see if data is already installed...
    # That is, we don't want to overwrite what's there, or spend the time initializing.
    # In the initialization we drop a .homer_initialized file as a semaphore, and we load based on its presence.
    if [[ ! -f $DATADIR/.homer_initialized ]]; then
      # Run the load data function if that table doesn't exist
      MYSQL_INITIAL_DATA_LOAD
    else
      echo "Found existing data..."
      MYSQL_RUN
    fi

    # Reconfigure rotation
    export PATH_ROTATION_CONFIG=/opt/rotation.ini
    perl -p -i -e "s/homer_user/$DB_USER/" $PATH_ROTATION_CONFIG
    perl -p -i -e "s/homer_password/$DB_PASS/" $PATH_ROTATION_CONFIG
    perl -p -i -e "s/localhost/$DB_HOST/" $PATH_ROTATION_CONFIG
    /opt/homer_mysql_rotate.pl > /dev/null 2>&1

    # Start the cron service in the background for rotation
    cron -f &

fi

# OPENSIPS CONFIG
PATH_OPENSIPS_M4=/etc/opensips/opensips.m4
PATH_OPENSIPS_CFG=/etc/opensips/opensips.cfg
if ! [ -e "$PATH_OPENSIPS_CFG" ]; then
    # OpenSIPS not initialized yet - doing it now
    m4 -D LISTEN_PORT=$LISTEN_PORT \
        -D DB_PASS=$DB_PASS \
        -D DB_HOST=$DB_HOST \
        -D DB_USER=$DB_USER \
        $PATH_OPENSIPS_M4 > $PATH_OPENSIPS_CFG.template
    chmod 775 $PATH_OPENSIPS_CFG.template
fi

PATH_OPENSIPS_ES_M4=/etc/opensips/opensips-es.m4
PATH_OPENSIPS_ES_CFG=/etc/opensips/opensips-es.cfg
if ! [ -e "$PATH_OPENSIPS_ES_CFG" ]; then
    # OpenSIPS not initialized yet - doing it now
    m4 -D LISTEN_PORT=$LISTEN_PORT \
        -D DB_PASS=$DB_PASS \
        -D DB_HOST=$DB_HOST \
        -D DB_USER=$DB_USER \
        -D ES_URL=${ES_URL:-$DEFAULT_ES_URL} \
        $PATH_OPENSIPS_ES_M4 > $PATH_OPENSIPS_ES_CFG.template
    chmod 775 $PATH_OPENSIPS_ES_CFG.template
fi

# Push ES Template for HOMER Data
HOMER_TEMPLATE="/etc/homer-es-template.json"
if [ $ES_STATUS = "enabled" ]; then
	[ -e "$HOMER_TEMPLATE" ] && \
		curl -XPUT "$ES_URL/_template/homer_template" \
			--data $HOMER_TEMPLATE
	[ -e "$PATH_OPENSIPS_CFG" ] || \
		cp $PATH_OPENSIPS_ES_CFG.template $PATH_OPENSIPS_CFG
else
	[ -e "$PATH_OPENSIPS_CFG" ] || \
		cp $PATH_OPENSIPS_CFG.template $PATH_OPENSIPS_CFG
fi

# Make an alias, kinda.
opensips=$(which opensips)

service rsyslog start
touch /var/log/opensips.log

# Test the syntax.
$opensips -f $PATH_OPENSIPS_CFG -c

#enable apache mod_php and mod_rewrite
a2enmod php5
a2enmod rewrite

# Start Apache
# apachectl -DFOREGROUND
rm -f /var/run/apache2/apache2.pid 2> /dev/null
apachectl start


# It's Homer time!
/usr/sbin/opensipsctl start && /usr/sbin/opensipsctl start

tail -f /var/log/opensips.log
