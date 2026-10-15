FROM debian:jessie
MAINTAINER L. Mangani <lorenzo.mangani@gmail.com>
# v.5.x

# Default baseimage settings
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive

# Update and upgrade apt
RUN apt-get update -qq \
 && apt-get install --no-install-recommends --no-install-suggests -yqq ca-certificates perl libdbi-perl libclass-dbi-mysql-perl apache2 libapache2-mod-php5 php5 php5-cli php5-gd php-pear php5-dev php5-mysql php5-json php-services-json git wget pwgen curl && rm -rf /var/lib/apt/lists/* \
 && a2enmod php5

# Install MySQL 5.7
RUN echo "Installing MySQL 5.7..." \
  && echo "deb http://repo.mysql.com/apt//debian/ jessie mysql-apt-config" >> /etc/apt/sources.list \
  && echo "deb http://repo.mysql.com/apt//debian/ jessie mysql-5.7" >> /etc/apt/sources.list \
  && echo "deb http://repo.mysql.com/apt//debian/ jessie connector-python-2.0 connector-python-2.1 router-2.0 mysql-utilities-1.5 mysql-tools" >> /etc/apt/sources.list \
  && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8C718D3B5072E1F5 && apt-get update && apt-get -y --no-install-recommends install mysql-community-server libmysqlclient20
  # && echo -e "\ncharacter-set-server=utf8 \ncollation-server=utf8_general_ci \nskip-character-set-client-handshake" >> /etc/mysql/my.cnf


# comment out a few problematic configuration values
# don't reverse lookup hostnames, they are usually another container
# RUN sed -Ei 's/^(bind-address|log)/#&/' /etc/mysql/my.cnf \
  RUN  echo 'skip-host-cache\nskip-name-resolve' | awk '{ print } $1 == "[mysqld]" && c == 0 { c = 1; system("cat") }' /etc/mysql/my.cnf > /tmp/my.cnf \
	&& mv /tmp/my.cnf /etc/mysql/my.cnf

WORKDIR /

# HOMER 5
RUN git clone https://github.com/sipcapture/homer-api.git /homer-api \
 && git clone https://github.com/sipcapture/homer-ui.git /homer-ui \

 && chmod -R +x /homer-api/scripts/mysql/* && cp -R /homer-api/scripts/mysql/. /opt/ \
 && cp -R /homer-ui/* /var/www/html/ \
 && cp -R /homer-api/api /var/www/html/ \
 && chown -R www-data:www-data /var/www/html/store/ \
 && chmod -R 0775 /var/www/html/store/dashboard \

 && wget https://raw.githubusercontent.com/sipcapture/homer-config/master/docker/configuration.php -O /var/www/html/api/configuration.php \
 && wget https://raw.githubusercontent.com/sipcapture/homer-config/master/docker/preferences.php -O /var/www/html/api/preferences.php \
 && wget https://raw.githubusercontent.com/sipcapture/homer-config/master/docker/vhost.conf -O /etc/apache2/sites-enabled/000-default.conf

# OpenSIPS + sipcapture module
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 049AD65B \
 && echo "deb http://apt.opensips.org jessie 2.2-releases" >>/etc/apt/sources.list \
 && apt-get update -qq && apt-get install -f -yqq rsyslog opensips opensips-geoip-module opensips-json-module opensips-mysql-module opensips-regex-module opensips-restclient-module  && rm -rf /var/lib/apt/lists/* \
 && rm /etc/opensips/opensips.cfg

COPY data/opensips.m4 /etc/opensips/opensips.m4
COPY data/opensips-es.m4 /etc/opensips/opensips-es.m4
RUN chmod 775 /etc/opensips/opensips.m4 && chmod 775 /etc/opensips/opensips-es.m4

# GeoIP (http://dev.maxmind.com/geoip/legacy/geolite/)
RUN apt-get update -qq && apt-get install -f -yqq geoip-database geoip-database-extra \
# Install the cron service
 && touch /var/log/cron.log \ 
 && apt-get install cron -y \

# Add our crontab file
 && echo "30 3 * * * /opt/homer_mysql_rotate.pl >> /var/log/cron.log 2>&1" > /etc/cron.d/homer_mysql_rotate.conf \
 && echo "local0.* -/var/log/opensips.log" > /etc/rsyslog.d/opensips.conf 

COPY run.sh /run.sh
RUN chmod a+rx /run.sh

COPY data/homer-es-template.json /etc/homer-es-template.json

# Add persistent MySQL volumes
# VOLUME ["/etc/mysql", "/var/lib/mysql", "/var/www/html/store"]

# UI
EXPOSE 80
# HEP
EXPOSE 9060

ENTRYPOINT ["/run.sh"]
