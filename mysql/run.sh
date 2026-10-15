#!/bin/bash
# ----------------------------------------------------
# HOMER 5 Docker (http://sipcapture.org)

if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
  ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
  echo "${TZ}" >/etc/timezone
  export TZ
fi
# ----------------------------------------------------
# -- To facilitate starting (or not starting) MySQL
# -- based on option to use remote mysql.
# ----------------------------------------------------
# Reads from environment variables to set:
# USE_REMOTE_MYSQL        If true, does not start mysql

if [[ "$USE_REMOTE_MYSQL" = true ]]; then
	echo "MySQL existing, not necessary."
else
	./entrypoint.sh mysqld
fi
