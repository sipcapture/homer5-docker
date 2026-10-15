#!/bin/bash
# HOMER 5 Docker (http://sipcapture.org)
# run.sh {parameters}

if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
  ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
  echo "${TZ}" >/etc/timezone
  export TZ
fi

# HOMER Options, defaults (CLI flags override env; see issues #20 / #59)
DB_USER="${DB_USER:-homer_user}"
DB_PASS="${DB_PASS:-homer_password}"
DB_HOST="${DB_HOST:-127.0.0.1}"
LISTEN_PORT="${KAMAILIO_HEP_PORT:-9060}"

# HOMER MySQL Options, defaults
sqluser=root
sqlpassword="${MYSQL_ROOT_PASSWORD:-secret}"

# Container
DOCK_IP="127.0.0.1"

show_help() {
cat << EOF
Usage: ${0##*/} [--hep 9060]
Homer5 Docker parameters:

    --dbpass -p             MySQL password (homer_password)
    --dbuser -u             MySQL user (homer_user)
    --dbhost -h             MySQL host (127.0.0.1 [docker0 bridge])
    --mypass -P             MySQL root local password (secret)
    --hep    -H             Kamailio HEP Socket port (9060)

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
    --help )
       	show_help;
       	exit 0 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

configure_rotation() {
  export PATH_ROTATION_CONFIG=/opt/rotation.ini
  perl -p -i -e "s/homer_user/$DB_USER/" $PATH_ROTATION_CONFIG
  perl -p -i -e "s/homer_password/$DB_PASS/" $PATH_ROTATION_CONFIG
  perl -p -i -e "s/localhost/$DB_HOST/" $PATH_ROTATION_CONFIG
  perl -p -i -e 's/\(`session_id`\)/(`session_id`(255))/' /opt/homer_mysql_rotate.pl
  perl -p -i -e 's/\(`correlation_id`\)/(`correlation_id`(255))/' /opt/homer_mysql_rotate.pl
  /opt/homer_mysql_rotate.pl >/dev/null 2>&1
  sed -i 's/^\(session\s\+required\s\+pam_loginuid\.so.*$\)/# \1/g' /etc/pam.d/cron
  cron -f &
}

# HOMER API CONFIG
PATH_HOMER_CONFIG=/var/www/html/api/configuration.php
chmod 775 $PATH_HOMER_CONFIG

# Replace values in template
perl -p -i -e "s/\{\{ DB_PASS \}\}/$DB_PASS/" $PATH_HOMER_CONFIG
perl -p -i -e "s/\{\{ DB_HOST \}\}/$DB_HOST/" $PATH_HOMER_CONFIG
perl -p -i -e "s/\{\{ DB_USER \}\}/$DB_USER/" $PATH_HOMER_CONFIG

# Set Permissions for webapp
mkdir -p /var/www/html/api/tmp
chmod -R 0777 /var/www/html/api/tmp/
chmod -R 0775 /var/www/html/store/dashboard*

#MySQL Reconfig defaults
PATH_MYSQL_CONFIG=/etc/mysql/my.cnf
perl -p -i -e "s/sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES/sql_mode=NO_ENGINE_SUBSTITUTION/" $PATH_MYSQL_CONFIG
sed '/\[mysqld\]/a max_connections = 1024\' -i $PATH_MYSQL_CONFIG


# MYSQL SETUP
SQL_LOCATION=/homer-api/sql/mysql
DATADIR=/var/lib/mysql

# Handy-dandy MySQL run function
function MYSQL_RUN () {

  chown -R mysql:mysql "$DATADIR"    

  echo 'Starting mysqld'
  /etc/init.d/mysql start
  while [ ! -S /var/run/mysqld/mysqld.sock ]; do
      sleep 1
  done

}

# MySQL data loading function (embedded/local MySQL)
function MYSQL_INITIAL_DATA_LOAD () {
  echo "Beginning initial data load...."

  chown -R mysql:mysql "$DATADIR"
  mysqld --initialize-insecure=on --user=mysql --datadir="$DATADIR"

  MYSQL_RUN

  echo "Creating Databases..."
  mysql --host "$DB_HOST" -u "$sqluser" < $SQL_LOCATION/homer_databases.sql
  mysql --host "$DB_HOST" -u "$sqluser" < $SQL_LOCATION/homer_user.sql
  
  mysql --host "$DB_HOST" -u "$sqluser" -e "GRANT ALL ON *.* TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS'; FLUSH PRIVILEGES;";
  echo "Creating Tables..."
  mysql --host "$DB_HOST" -u "$sqluser" homer_data < $SQL_LOCATION/schema_data.sql
  mysql --host "$DB_HOST" -u "$sqluser" homer_configuration < $SQL_LOCATION/schema_configuration.sql
  mysql --host "$DB_HOST" -u "$sqluser" homer_statistic < $SQL_LOCATION/schema_statistic.sql
  
  mysql --host "$DB_HOST" -u "$sqluser" homer_configuration -e "REPLACE INTO node VALUES(1,'mysql','homer_data','3306','"$DB_USER"','"$DB_PASS"','sip_capture','node1', 1);"
  
  echo 'Setting root password....'
  mysql -u root -e "SET PASSWORD = PASSWORD('$sqlpassword');" 

  echo "Homer initial data load complete" > $DATADIR/.homer_initialized
}

function MYSQL_REMOTE_BOOTSTRAP () {
  export MYSQL_PWD=$sqlpassword
  echo "Waiting for remote MySQL at $DB_HOST..."
  waited=0
  while ! mysqladmin -h "$DB_HOST" -u "$sqluser" status &>/dev/null; do
    sleep 2
    waited=$((waited + 2))
    if [ "$waited" -ge 300 ]; then
      echo "Remote MySQL at $DB_HOST did not become reachable in time."
      exit 1
    fi
  done

  databases=$(mysql -h "$DB_HOST" -u "$sqluser" -s -e 'show databases;')
  if [[ ! "$databases" =~ "homer_data" ]]; then
    echo "Beginning remote initial data load on $DB_HOST..."
    mysql --host "$DB_HOST" -u "$sqluser" < $SQL_LOCATION/homer_databases.sql
    mysql --host "$DB_HOST" -u "$sqluser" < $SQL_LOCATION/homer_user.sql
    mysql --host "$DB_HOST" -u "$sqluser" -e "GRANT ALL ON *.* TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS'; FLUSH PRIVILEGES;"
    export MYSQL_PWD=$DB_PASS
    mysql --host "$DB_HOST" -u "$DB_USER" homer_data < $SQL_LOCATION/schema_data.sql
    mysql --host "$DB_HOST" -u "$DB_USER" homer_configuration < $SQL_LOCATION/schema_configuration.sql
    mysql --host "$DB_HOST" -u "$DB_USER" homer_statistic < $SQL_LOCATION/schema_statistic.sql
    mysql --host "$DB_HOST" -u "$DB_USER" homer_configuration -e "REPLACE INTO node VALUES(1,'$DB_HOST','homer_data','3306','"$DB_USER"','"$DB_PASS"','sip_capture','node1', 1);"
  else
    echo "Remote Homer databases already present on $DB_HOST."
  fi
}

if [ "$DB_HOST" = "$DOCK_IP" ]; then
    if [[ ! -f $DATADIR/.homer_initialized ]]; then 
      MYSQL_INITIAL_DATA_LOAD
    else
      echo "Found existing data..."
      MYSQL_RUN
    fi
    configure_rotation
else
    MYSQL_REMOTE_BOOTSTRAP
    configure_rotation
fi

# KAMAILIO CONFIG
export PATH_KAMAILIO_CFG=/etc/kamailio/kamailio.cfg

awk '/max_while_loops=100/{print $0 RS "mpath=\"//usr/lib/x86_64-linux-gnu/kamailio/modules/\"";next}1' $PATH_KAMAILIO_CFG >> $PATH_KAMAILIO_CFG.tmp | 2&>1 >/dev/null
mv $PATH_KAMAILIO_CFG.tmp $PATH_KAMAILIO_CFG

perl -p -i -e "s/\{\{ LISTEN_PORT \}\}/$LISTEN_PORT/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ DB_PASS \}\}/$DB_PASS/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ DB_HOST \}\}/$DB_HOST/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ DB_USER \}\}/$DB_USER/" $PATH_KAMAILIO_CFG

kamailio=$(which kamailio)
$kamailio -f $PATH_KAMAILIO_CFG -c

a2enmod php5
a2enmod rewrite 

apachectl start
$kamailio -f $PATH_KAMAILIO_CFG -DD -E -e
