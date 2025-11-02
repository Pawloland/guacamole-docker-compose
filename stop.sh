#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_DIR="$SCRIPT_DIR"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose.yml"

tailscale funnel --bg https+insecure://127.0.0.1:8443 off 2>/dev/null
docker compose -f "$DOCKER_COMPOSE_FILE" stop
