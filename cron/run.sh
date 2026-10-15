#!/bin/bash
# ----------------------------------------------------
# HOMER 5 Docker (http://sipcapture.org)

if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
  ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
  echo "${TZ}" >/etc/timezone
  export TZ
fi
# ----------------------------------------------------
# -- Run script for Homer's cron jobs
# ----------------------------------------------------
# Reads from environment variables to set:
# DB_PASS             MySQL password (homer_password)
# DB_USER             MySQL user (homer_user)
# DB_HOST             MySQL host (127.0.0.1 [docker0 bridge])
# ----------------------------------------------------

while [[ ! -f "/homer-semaphore/.bootstrapped" ]]; do
  echo "Homer cron container, waiting for MySQL"
  sleep 2;
done

# Work around key size constraints (noted in issue @ https://github.com/sipcapture/homer-docker/issues/42)
perl -p -i -e 's/\(`session_id`\)/(`session_id`(255))/' /opt/homer_mysql_rotate.pl 
perl -p -i -e 's/\(`correlation_id`\)/(`correlation_id`(255))/' /opt/homer_mysql_rotate.pl


# Reconfigure rotation

# --- I believe these are deprecated (@dougbtv, 3/30/17)
# export PATH_ROTATION_SCRIPT=/opt/homer_rotate
# chmod 775 $PATH_ROTATION_SCRIPT
# chmod +x $PATH_ROTATION_SCRIPT

export PATH_ROTATION_CONFIG=/opt/rotation.ini

perl -p -i -e "s/homer_user/$DB_USER/" $PATH_ROTATION_CONFIG
perl -p -i -e "s/homer_password/$DB_PASS/" $PATH_ROTATION_CONFIG
perl -p -i -e "s/localhost/$DB_HOST/" $PATH_ROTATION_CONFIG

# --- I believe these are deprecated (@dougbtv, 3/30/17)
# PERL_SCRIPTS=(/opt/homer_mysql_new_table.pl /opt/homer_mysql_partrotate_unixtimestamp.pl)
# for perl_script in ${PERL_SCRIPTS[@]}
# do
#   perl -p -i -e "s/homer_user/$DB_USER/" $perl_script
#   perl -p -i -e "s/homer_password/$DB_PASS/" $perl_script
#   perl -p -i -e "s/mysql_host = \"localhost\"/mysql_host = \"$DB_HOST\"/" $perl_script
# done

# Init rotation
/opt/homer_mysql_rotate.pl

# Ensure cron is allowed to run
sed -i 's/^\(session\s\+required\s\+pam_loginuid\.so.*$\)/# \1/g' /etc/pam.d/cron

# Start the cron service in the foreground, which will run rotation
cron -f
