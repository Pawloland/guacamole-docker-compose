#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_DIR="$SCRIPT_DIR"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose.yml"

echo "Stopping Tailscale funnel"
tailscale funnel --bg https+insecure://127.0.0.1:8443 off 2>/dev/null
echo "done"
echo "Stopping Docker containers"
docker compose -f "$DOCKER_COMPOSE_FILE" stop
echo "done"
