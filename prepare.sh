#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_DIR="$SCRIPT_DIR"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose.yml"
DOCKER_COMPOSE_GUACAMOLE_SERVICE_NAME="guacamole_base"


# check if docker is running
if ! (docker ps >/dev/null 2>&1)
then
	echo "docker daemon not running, will exit here!"
	exit
fi
echo "Preparing folder init and creating ./init/initdb.sql"
mkdir "$SCRIPT_DIR/init" > /dev/null 2>&1
mkdir -p "$SCRIPT_DIR/nginx/ssl" > /dev/null 2>&1
chmod -R +x "$SCRIPT_DIR/init"

docker compose -f "$DOCKER_COMPOSE_FILE" run --rm "$DOCKER_COMPOSE_GUACAMOLE_SERVICE_NAME" /opt/guacamole/bin/initdb.sh --postgresql > "$SCRIPT_DIR/init/initdb.sql"
echo "done"
echo "Preparing folder record and set permissions"
mkdir "$SCRIPT_DIR/record" > /dev/null 2>&1
chmod -R 777 "$SCRIPT_DIR/record"
echo "done"
echo "Creating SSL certificates"
openssl req -nodes -newkey rsa:2048 -new -x509 -keyout "$SCRIPT_DIR/nginx/ssl/self-ssl.key" -out "$SCRIPT_DIR/nginx/ssl/self.cert" -subj '/C=DE/ST=BY/L=Hintertupfing/O=Dorfwirt/OU=Theke/CN=www.createyourown.domain/emailAddress=docker@createyourown.domain'
echo "You can use your own certificates by placing the private key in \"$SCRIPT_DIR/nginx/ssl/self-ssl.key\" and the cert in \"$SCRIPT_DIR/nginx/ssl/self.cert\""
echo "Creating empty allowlist_database.txt and allowlist.conf"
echo "done"
touch "$SCRIPT_DIR/allowlist_database.txt"
touch "$SCRIPT_DIR/nginx/allowlist.conf"
echo "done"
