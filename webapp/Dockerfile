FROM debian:jessie
MAINTAINER L. Mangani <lorenzo.mangani@gmail.com>
# v.5.02

# Default baseimage settings
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive

ENV BUILD_DATE 2018-08-12

# Update and upgrade apt
RUN apt-get update -qq
# RUN apt-get upgrade -y
RUN apt-get install --no-install-recommends --no-install-suggests -yqq ca-certificates apache2 libapache2-mod-php5 php5 php5-cli php5-gd php-pear php5-dev php5-mysql php5-json php-services-json git wget pwgen perl libdbi-perl libclass-dbi-mysql-perl && rm -rf /var/lib/apt/lists/*
RUN a2enmod php5

# HOMER 5
ENV HOMER_VERSION_CACHE_BUSTER arbitrary_value_0x000000d00d

RUN git clone https://github.com/sipcapture/homer-api.git /homer-api && cd /homer-api 
RUN git clone https://github.com/sipcapture/homer-ui.git /homer-ui && cd /homer-ui 

WORKDIR /

RUN chmod -R +x /homer-api/scripts/mysql/*
RUN cp -R /homer-api/scripts/mysql/. /opt/

RUN cp -R /homer-ui/* /var/www/html/
RUN cp -R /homer-api/api /var/www/html/
RUN chown -R www-data:www-data /var/www/html/store/
RUN chmod -R 0775 /var/www/html/store/dashboard

COPY configuration.php /var/www/html/api/configuration.php
COPY preferences.php /var/www/html/api/preferences.php
COPY vhost.conf /etc/apache2/sites-enabled/000-default.conf

COPY run.sh /run.sh
RUN chmod a+rx /run.sh

# Add persistent volumes
VOLUME ["/var/www/html/store"]

# UI
EXPOSE 80

ENTRYPOINT ["/run.sh"]
