#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_DIR="$SCRIPT_DIR"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose.yml"

usage() {
    echo "Usage: $(basename "$0") [Option]"
    echo
    echo "Options:"
    echo "  -n, --no-funnel    Disable Tailscale funnel after starting Docker services."
    echo "  -c, --cloudflare   Start free cloudflare tunnel in addition to Tailscale funnel."
    echo "  -h, --help         Show this help message and exit."
    exit 1
}

# --- Parse arguments ---
DISABLE_FUNNEL=0
ENABLE_CLOUDFLARE=0

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
        -c|--cloudflare)
            ENABLE_CLOUDFLARE=1
            echo "Cloudflare tunnel will be enabled in addition to Tailscale funnel."
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
if [[ $ENABLE_CLOUDFLARE -eq 1 && $DISABLE_FUNNEL -eq 0 ]]; then
    echo "Starting cloudflare tunnel container"
    docker compose -f "$DOCKER_COMPOSE_FILE" up cloudflared -d --wait
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to start cloudflare tunnel container."
        exit 1
    fi
fi

docker compose -f "$DOCKER_COMPOSE_FILE" up -d
DOCKER_STATUS=$?
echo "done"

# --- Start Tailscale funnel if enabled ---
if [[ $DISABLE_FUNNEL -eq 0 && $DOCKER_STATUS -eq 0 ]]; then
    echo "Starting Tailscale funnel"
    tailscale funnel --bg https+insecure://127.0.0.1:8443
    echo "done"

    if [[ $ENABLE_CLOUDFLARE -eq 1 ]]; then
        echo "Cloudflare tunnel is enabled in addition to Tailscale funnel."
        echo "It is accessible under /cf path on the Tailscale Funnell domain:"
        DNS=$(tailscale status --json | jq -r '.Self.DNSName')
        DNS="${DNS%.}"
        echo "https://$DNS/cf"
        echo "and will redirect to:"
        cat "$SCRIPT_DIR/cloudflared/cloudflare_redirect.conf" | grep -m1 -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com'
    fi

fi
