#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_DIR="$SCRIPT_DIR"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose.yml"

usage() {
    echo "Usage: $(basename "$0") [--no-funnel]"
    echo
    echo "Options:"
    echo "  -n, --no-funnel    Disable Tailscale funnel after starting Docker services"
    echo "  -h, --help         Show this help message and exit"
    exit 1
}

# --- Parse arguments ---
DISABLE_FUNNEL=0

if [[ $# -gt 1 ]]; then
    echo "Error: Too many arguments."
    usage
fi

if [[ $# -eq 1 ]]; then
    case "$1" in
        -n|--no-funnel)
            DISABLE_FUNNEL=1
            echo "Tailscale funnel will not be enabled if it is disabled."
            echo "It will not be disabled if it was already running."
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option '$1'"
            usage
            ;;
    esac
fi

echo "Starting Docker containers"
docker compose -f "$DOCKER_COMPOSE_FILE" up -d
DOCKER_STATUS=$?
echo "done"

# --- Start Tailscale funnel if enabled ---
if [[ $DISABLE_FUNNEL -eq 0 && $DOCKER_STATUS -eq 0 ]]; then
    echo "Starting Tailscale funnel"
    tailscale funnel --bg https+insecure://127.0.0.1:8443
    echo "done"
fi
