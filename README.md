
![homer](http://i.imgur.com/ViXcGAD.png)

# HOMER 5 Docker
http://sipcapture.org

A simple recipe to bring up a quick, self-contained Homer5 instance:

* debian/jessie (base image)
* Kamailio4.x:9060 (sipcapture module)
* Apache2/PHP5:80 (homer ui/api)
* MySQL5.6/InnoDB:3306 (homer db/data)

Status: 

* [![Build Status](https://travis-ci.org/sipcapture/homer-docker.svg?branch=master)](https://travis-ci.org/sipcapture/homer-docker)

* Initial working prototype - Testing Needed!
 
## Running multi-containers

### Mult-container quick-start

```bash
git clone https://github.com/sipcapture/homer-docker.git
cd homer-docker
docker-compose build
docker-compose up
```

### Using docker-compose

It's encouraged as a [best practice](https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/) to deploy separate containers for each process. To specify what's required to build & run each container, it's recommended to use [docker-compose](https://docs.docker.com/compose/install/). The linked document explains a number of ways to install it, however, we'll recommend installing it using Docker (as if you're using this, your system likely has it!). Requires Docker 1.10 or greater.

```bash
$ curl -L https://github.com/docker/compose/releases/download/1.6.2/run.sh > /usr/local/bin/docker-compose
$ chmod +x /usr/local/bin/docker-compose
$ docker-compose --version
```

### Bringing up all the containers

All that should be required is to, in the root of this clone, issue:

```bash
$ docker-compose up
```

Which will spin up all the containers, and it will show you the logs (the STDOUT from the foreground process) as you move along. You can stop the containers by hitting `ctrl-c`.  In production, you'll want to detach from the `docker-compose up` command which can be achieved with the `-d` option, a la...

```bash
$ docker-compose up -d
```

### Modifying the default options

There's a `homer.env` file with environment variables in the root of the clone, which by default should work just fine. 

For example you may choose to use a remote mysql host rather than have the one contained herein, if that is so, change the `USE_REMOTE_MYSQL` to true, and specify the `DB_HOST` as 

It is recommended to change the MySQL and homer passwords in your own setup, especially in production.


### Using the data volumes

The `docker-compose` scheme will create [named data volumes](https://docs.docker.com/engine/reference/commandline/volume_create/) to store the mysql data. You can find the volumes it has created with:

```bash
$ docker volume ls | grep -i homer
```

### Starting anew

So, you'd like to remove everything you've done up to this point? And start 'er fresh run `docker-compose down` and remove the data containers...

```bash
$ docker-compose down

# Warning this will delete all of your mysql data!
$ docker volume rm $(docker volume ls | grep -i homer | awk '{print $2}')
```

Docker will warn if you the data container is already in use, and you must stop and remove any containers which have those volumes in use.

---------

## Running in a single container.

While the multi-container setup is recommended, you can find the legacy container for running all processes in a single volume in the `everything/` folder.

### Pull latest
```
docker pull sipcapture/homer-docker
```

### Run latest
```
docker run -tid --name homer5 -p 80:80 -p 9060:9060/udp sipcapture/homer-docker
```

### Running with a local MySQL

By default, the container runs with a local instance of MySQL running. It may be of interest to run MySQL with a host directory mounted as a volume for MySQL data. This will help with keeping persistent data if you need to stop & remove the running container. (Which would otherwise delete the MySQL, without a mounted volume)

You can run this container with a volume like so:

```
docker run -it -v /tmp/homer_mysql/:/var/lib/mysql --name homer5 -p 80:80 -p 9060:9060/udp sipcapture/homer-docker
```

### Running with an external MySQL

If you'd like to run with an external MySQL, pass in the host information for the remote MySQL as entrypoint parameters at the end of your `docker run` command.

```
docker run -tid --name homer5 -p 80:80 -p 9060:9060/udp sipcapture/homer-docker --dbhost 10.0.0.1 --dbuser homer_user -dbpass homer_password
```

### Entrypoint Parameters

For single-container only.

```
Homer5 Docker parameters:

    --dbpass -p             MySQL password (homer_password)
    --dbuser -u             MySQL user (homer_user)
    --dbhost -h             MySQL host (127.0.0.1 [docker0 bridge])
    --mypass -P             MySQL root local password (secret)
    --hep    -H             Kamailio HEP Socket port (9060)
```

### Local Build & Test
```
git clone https://github.com/sipcapture/homer-docker; cd homer-docker
docker build --tag="sipcapture/homer-docker:local" ./everything/
docker run -t -i sipcapture/homer-docker:local --name homer5
docker exec -it homer5 bash
```

### Appendix - Destination Stats

By defining `WITH_HOMER_DEST_STATS` in kamailio.cfg it's possible to enable capturing data related to the dialled country, prefix, geolocation and duration.

The data is transported inside a SIP header, `P-Dest-Stats`.

Example:

```
P-Dest-Stats: CC=es;PR=+349;Dur=138;Lat=0;Lon=0
```

Kamailio will do two things:

1. Populate the table `homer_statistic.stats_dest_mem` as soon as that header is found in a SIP message

2. Every 5 minutes summarise the stats into `homer_statistic.stats_dest_reply` and empty `homer_statistic.stats_dest_mem`

The data from `homer_statistic.stats_dest_reply` can be presented inside a `Sipcapture Stats` widget.

