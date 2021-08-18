FROM mysql:5.6
MAINTAINER @qxip (twitter)
RUN apt-get update && apt-get install -y git
RUN git clone https://github.com/sipcapture/homer-api.git /homer-api && cd /homer-api && cd /
ADD bootstrap.sh /bootstrap.sh
