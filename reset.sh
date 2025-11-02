#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_DIR="$SCRIPT_DIR"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose.yml"

echo "This will stop all running containers, close Tailscale funnel and: "
echo "      delete your existing database   (\"$SCRIPT_DIR/data/\")"
echo "      delete database init files      (\"$SCRIPT_DIR/init/\")"
echo "      delete your recordings          (\"$SCRIPT_DIR/record/\")"
echo "      delete your drive files         (\"$SCRIPT_DIR/drive/\")"
echo "      delete your certs files         (\"$SCRIPT_DIR/nginx/ssl/\")"
echo "      delete your current allowlist   (\"$SCRIPT_DIR/allowlist_database.txt and $SCRIPT_DIR/nginx/allowlist.conf\")"
echo "      delete all containers defined in \"$DOCKER_COMPOSE_FILE\""
read -p "Are you sure? [Y|N]" -n 1 -r
echo ""   # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]; then # do dangerous stuff
    echo "Running \"$SCRIPT_DIR/stop.sh\" to stop containers"
    . "$SCRIPT_DIR/stop.sh"
    docker compose -f "$DOCKER_COMPOSE_FILE" down
    chmod -R +x -- "$SCRIPT_DIR/init" 2>/dev/null
    sudo rm -r -f \
        "$SCRIPT_DIR/data/" \
        "$SCRIPT_DIR/init/" \
        "$SCRIPT_DIR/drive/" \
        "$SCRIPT_DIR/record/" \
        "$SCRIPT_DIR/nginx/ssl/" \
        "$SCRIPT_DIR/allowlist_database.txt" \
        "$SCRIPT_DIR/nginx/allowlist.conf"
    echo "All done."
else
    echo "Aborted. No resets were made."
fi

