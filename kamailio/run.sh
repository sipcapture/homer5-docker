#!/bin/bash
# ----------------------------------------------------
# HOMER 5 Docker (http://sipcapture.org)
# ----------------------------------------------------
# -- Run script for Homer's Kamailio
# ----------------------------------------------------
# Reads from environment variables to set:
# DB_PASS             MySQL password (homer_password)
# DB_USER             MySQL user (homer_user)
# DB_HOST             MySQL host (127.0.0.1 [docker0 bridge])
# DB_PORT             MySQL port (3306)
# KAMAILIO_HEP_PORT   Kamailio HEP Socket port (9060)
# ----------------------------------------------------

# Wait for MySQL

while [[ ! -f "/homer-semaphore/.bootstrapped" ]]; do
  echo "Kamailio, waiting for MySQL"
  sleep 2;
done

echo "Kamailio container detected MySQL is running & bootstrapped"

# Kamailio config
export PATH_KAMAILIO_CFG=/etc/kamailio/kamailio.cfg

awk '/max_while_loops=100/{print $0 RS "mpath=\"//usr/lib/x86_64-linux-gnu/kamailio/modules/\"";next}1' $PATH_KAMAILIO_CFG >> $PATH_KAMAILIO_CFG.tmp | 2&>1 >/dev/null
mv $PATH_KAMAILIO_CFG.tmp $PATH_KAMAILIO_CFG

# Replace values in template
perl -p -i -e "s/\{\{ CAPTURE_NODE \}\}/$CAPTURE_NODE/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ KAMAILIO_HEP_PORT \}\}/$KAMAILIO_HEP_PORT/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ DB_PASS \}\}/$DB_PASS/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ DB_HOST \}\}/$DB_HOST/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ DB_PORT \}\}/$DB_PORT/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ DB_USER \}\}/$DB_USER/" $PATH_KAMAILIO_CFG

# Change kamailio datestamp for sql tables
# sed -i -e 's/# $var(a) = $var(table) + "_" + $timef(%Y%m%d);/$var(a) = $var(table) + "_" + $timef(%Y%m%d);/' $PATH_KAMAILIO_CFG
# sed -i -e 's/$var(a) = $var(table) + "_%Y%m%d";/# runscript removed -- $var(a) = $var(table) + "_%Y%m%d";/' $PATH_KAMAILIO_CFG

# Make an alias, kinda.
kamailio=$(which kamailio)

# Test the syntax.
$kamailio -f $PATH_KAMAILIO_CFG -c

# It's Homer time!
$kamailio -f $PATH_KAMAILIO_CFG -DD -E -e

