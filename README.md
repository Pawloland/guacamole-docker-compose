# Guacamole with docker compose
This is a small documentation how to run a fully working **Apache Guacamole (incubating)** instance with docker (docker compose). The goal of this project is to make it easy to test Guacamole from the internet using [Tailscale Funnel](https://tailscale.com/kb/1223/funnel) while also providing a basic IP allowlist functionality to restrict access to only trusted IP addresses.

> **DO NOT USE THIS REPO for PRODUCTIVE USE!**

## About Guacamole
Apache Guacamole (incubating) is a clientless remote desktop gateway. It supports standard protocols like VNC, RDP, and SSH. It is called clientless because no plugins or client software are required. Thanks to HTML5, once Guacamole is installed on a server, all you need to access your desktops is a web browser.

It supports RDP, SSH, Telnet and VNC and is the fastest HTML5 gateway I know. Checkout the projects [homepage](https://guacamole.incubator.apache.org/) for more information.

## Prerequisites
You need a working **docker** installation and **docker compose** running on your machine.
Tailscale should also be installed. Without it the setup will still work, but only on the docker host under `https://127.0.0.1:8443`.

## Quick start
Clone the GIT repository and start guacamole:

~~~bash
git clone "https://github.com/Pawloland/guacamole-docker-compose.git"
cd guacamole-docker-compose
./prepare.sh # only needed on first run to prepare database init script and self-signed ssl cert
./start.sh # to start the guacamole server and Tailscale funnel

# The initial login to the guacamole webinterface is:
#
#     Username: guacadmin
#     Password: guacadmin
#
# Make sure you change it immediately!

./ip_manage.sh # to manage IP allowlist for Tailscale funnel access and see current config
./stop.sh # to stop the guacamole server and Tailscale funnel
~~~

Your guacamole server will be available at `https://127.0.0.1:8443/` and also under `https://your-ts-dev-name.your-tailnet-name.ts.net/`. The default username is `guacadmin` with password `guacadmin`.

To edit IP address allowlist that will be able to access the website from the internet exposed 
though tailscale funnel please use `ip_manage.sh` script. It will create file `allowlist_database.txt` based on which nginx
config file is generated. To update rules without restarting container please select option `S - Save & Apply changes` and then you can check the current nginx config with option `C - Show running ngnix config`.
Please do not edit `allowlist.conf` file diretly as it will be overwritten by `ip_manage.sh` script.
Only use script to manage IP allowlist or edit `allowlist_database.txt` file directly if you are sure about the syntax.
If docker container is not running the `S - Save & Apply changes` option will just update `allowlist.conf` file,
and inform you that container is not running. The config will be automatically applied when the container is started next time.



## Details
To understand some details let's take a closer look at parts of the `docker-compose.yml` file:

### Name
The following part of docker-compose.yml will set the project name to `guacamole_compose`. Based on that name all containers will be named like `service_name_${COMPOSE_PROJECT_NAME}` where `${COMPOSE_PROJECT_NAME}` evaluates to `guacamole_compose`.
~~~python
...
name: guacamole_compose
...
~~~

### Networking
The following part of docker-compose.yml will create a network with name `network_guacamole_compose` in mode `bridged`.
~~~python
...
networks:
  network_guacamole_compose:
    driver: bridge
...
~~~

### Services
#### PostgreSQL
The following part of docker-compose.yml will create an instance of PostgreSQL using the official docker image. This image is highly configurable using environment variables. It will for example initialize a database if an initialization script is found in the folder `/docker-entrypoint-initdb.d` within the image. Since we map the local folder `./init` inside the container as `docker-entrypoint-initdb.d` we can initialize the database for guacamole using our own script (`./init/initdb.sql`). You can read more about the details of the official postgres image [here](https://hub.docker.com/_/postgres).

~~~python
...
  postgres:
    container_name: postgres_${COMPOSE_PROJECT_NAME}
    image: postgres:xxx
    environment:
      POSTGRES_DB: guacamole_db
      POSTGRES_PASSWORD: 'ChooseYourOwnPasswordHere1234'
      POSTGRES_USER: guacamole_user
    networks:
      - network_guacamole_compose
    volumes:
      - ./init:/docker-entrypoint-initdb.d:ro
      - ./data:/var/lib/postgresql/18/docker:rw
    restart: always
...
~~~

#### Guacd
The following part of docker-compose.yml will create the guacd service. guacd is the heart of Guacamole which dynamically loads support for remote desktop protocols (called "client plugins") and connects them to remote desktops based on instructions received from the web application. The container will be called `guacd_guacamole_compose` based on the docker image `guacamole/guacd` connected to our previously created network `guacnetwork_compose`. Additionally we map the 2 local folders `./drive` and `./record` into the container. We can use them later to map user drives and store recordings of sessions.

~~~python
...
  guacd:
    container_name: guacd_${COMPOSE_PROJECT_NAME}
    image: guacamole/guacd:xxx
    networks:
      - network_guacamole_compose
    volumes:
      - ./drive:/drive:rw
      - ./record:/record:rw
    depends_on:
      - postgres
    restart: always
...
~~~


#### Guacamole
The following part of docker-compose.yml will create an instance of guacamole by using the docker image `guacamole` from docker hub. It is also highly configurable using environment variables. In this setup it is configured to connect to the previously created postgres instance using a username and password and the database `guacamole_db`. Port 8080 is only accessible in docker network and isn't exposed directly! We will attach an instance of nginx for public facing of it in the next step.

~~~python
...
  guacamole:
    container_name: guacamole_${COMPOSE_PROJECT_NAME}
    image: guacamole/guacamole:xxx
    environment:
      GUACD_HOSTNAME: guacd
      POSTGRESQL_DATABASE: guacamole_db
      POSTGRESQL_HOSTNAME: postgres
      POSTGRESQL_PASSWORD: 'ChooseYourOwnPasswordHere1234'
      POSTGRESQL_USERNAME: guacamole_user
      RECORDING_SEARCH_PATH: /record
    networks:
      - network_guacamole_compose
    volumes:
      - ./record:/record:rw
    group_add:
      - "1000"
    depends_on:
      - guacd
    restart: always
...
~~~

#### nginx
The following part of docker-compose.yml will create an instance of nginx that maps the public port 8443 to the internal port 443. The internal port 443 is then mapped to guacamole using the `./nginx/templates/guacamole.conf.template` file. The container will use the previously generated (`prepare.sh`) self-signed certificate in `./nginx/ssl/` with `./nginx/ssl/self-ssl.key` and `./nginx/ssl/self.cert`.

~~~python
...
  nginx:
    container_name: nginx_guacamole_compose
    image: nginx:xxx

    networks:
      - network_guacamole_compose
    ports:
      # Bind to specific IP addresses (network interfaces) instead of all interfaces by default.
      # Binding to 0.0.0.0 by default can be risky because we can't ensure that all interfaces
      # are firewalled properly to limit only whitelisted IPs. Ngingx configuration assumes
      # that the connections come only from Tailscale funnel proxy (which can have floating IPs)
      # so it blindly trusts the X-Forwarded-For header for any incoming request 
      # to determine the original client IP.
      # Taislcale funnel proxy sets X-Forwarded-For header to the immidieate IP of the client 
      # connecting to the funnel proxy and overwrites it if already present 
      # (at least as of 02.11.2025 from my tests).
      # This means that no one can spoof that header to include one of whitelisted IPs 
      # when they are connecting through Tailscale funnel proxy (if connecting 
      # outside of funnel proxy then they can spoof it).
      # We can't determine if someone is connecting outside of Tailscale funnel proxy 
      # from withing nginx config, because the http request IP is always that of the docker internal network. 
      # This always looks like the request came from lan the container is running in. 
      #
      # If the X-Forwarded-For header is missing then the nginx config will accept the request because 
      # we can't verify that the request is coming from a whitelisted IP and the config assumes that 
      # the request originated from an allowed source like internal docker network, 
      # docker host (direct conneciton of docker host to 127.0.0.1:8443 which is an nginx service bind
      # on docker host) or a network that the docker host is connected to (like LAN, or tailnet) etc.
      #
      # This is a potential security risk when connecting outside of Tailscale funnel so make sure that 
      # any such conneciton path is properly firewalled above docker to only allow trusted IPs.
      # If someone can connect outside of Tailscale funnel, then they can spoof the X-Forwarded-For header
      # to include one of whitelisted IPs and gain access to the guacamole service or if the nginx service
      # is IP reachable, than ommiting the X-Forwarded-For header will also allow access.

      # The bellow is the desired network configuration so nginx instance with IP whitellist 
      # will be reachable only through the taialscale funnel that exposes nginx by using the command:
      # tailscale funnel --bg https+insecure://127.0.0.1:8443
      - 127.0.0.1:8443:443
    volumes:
      - ./nginx/templates:/etc/nginx/templates:ro
      - ./nginx/ssl/self.cert:/etc/nginx/ssl/self.cert:ro
      - ./nginx/ssl/self-ssl.key:/etc/nginx/ssl/self-ssl.key:ro
      - ./nginx/allowlist.conf:/etc/nginx/allowlist.conf:ro
    depends_on:
      - guacamole
    restart: always
...
~~~

## prepare.sh
`prepare.sh` is a small script that creates `./init/initdb.sql` by downloading the docker image `guacamole/guacamole` and starts it like this:

~~~bash
docker compose run --rm guacamole /opt/guacamole/bin/initdb.sh --postgresql > "./init/initdb.sql"
~~~

It creates the necessary database initialization file for postgres.

`prepare.sh` also creates the self-signed certificate `./nginx/ssl/self.cert` and the private key `./nginx/ssl/self-ssl.key` which are used
by nginx for https.


## start.sh
Starts the docker compose setup and the Tailscale funnel to expose guacamole to the internet.
If docker fails, then Tailscale funnel will not be opened.

## stop.sh
Stops all docker services and unconditionally closes the Tailscale funnel.

## ip_manage.sh
A small script to manage IP allowlist for Tailscale funnel access and see current config.
It creates/updates the file `nginx/allowlist.conf` based on the content of the file `database`.
If docker container is running it will also reload nginx config to apply changes immidietly when you select option `S - Save & Apply changes`.

## reset.sh
To reset everything to the beginning, just run `./reset.sh`.

## WOL

Wake on LAN (WOL) does not work and I will not fix that because it is beyound the scope of this repo. But [zukkie777](https://github.com/zukkie777) who also filed [this issue](https://github.com/boschkundendienst/guacamole-docker-compose/issues/12) fixed it. You can read about it on the [Guacamole mailing list](http://apache-guacamole-general-user-mailing-list.2363388.n4.nabble.com/How-to-docker-composer-for-WOL-td9164.html)

**Disclaimer**

Downloading and executing scripts from the internet may harm your computer. Make sure to check the source of the scripts before executing them!
