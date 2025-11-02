#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_DIR="$SCRIPT_DIR"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose.yml"
DOCKER_COMPOSE_NGINX_SERVICE_NAME="nginx"

DATABASE="$SCRIPT_DIR/allowlist_database.txt"
ALLOWLIST_FILE="$SCRIPT_DIR/nginx/allowlist.conf"

# Ensure the database file exists
touch "$DATABASE"

# Function to display current allowlist
show_allowlist() {
    echo -e "\nCurrent Allowed IPs:"
    if [[ ! -s "$DATABASE" ]]; then
        echo "[No IPs Whitelisted Yet]"
        return
    fi

    local index=1
    while IFS= read -r line; do
        echo "$index) $line"
        ((index++))
    done < "$DATABASE"
    echo ""
}

# Function to add a new IP
add_ip() {
    read -rp "Enter new IP or IP range: " new_ip
    echo "$new_ip" >> "$DATABASE"
    echo "Added: $new_ip"
}

# Function to edit an IP
edit_ip() {
	# Validate the index is numeric and within the valid range
    if [[ ! "$param" =~ ^[0-9]+$ ]]; then
        echo "Invalid index: Please provide a valid number."
        return
    fi
    old_ip=$(sed -n "${param}p" "$DATABASE")

    # Validate if the index exists
    if [[ -z "$old_ip" ]]; then
        echo "Invalid index: No entry found at index #$param"
        return
    fi

    echo "Current value: $old_ip"
    read -rp "Enter new IP or IP range: " new_ip
    sed -i "${param}s|.*|$new_ip|" "$DATABASE"
    echo "Updated entry #$param to: $new_ip"
}

# Function to delete an IP
delete_ip() {
	 # Validate the index is numeric and within the valid range
    if [[ ! "$param" =~ ^[0-9]+$ ]]; then
        echo "Invalid index: Please provide a valid number."
        return
    fi

    # Validate if the index exists
    if ! sed -n "${param}p" "$DATABASE" >/dev/null; then
        echo "Invalid index: No entry found at index #$param"
        return
    fi

    if ! sed -i "${param}d" "$DATABASE"; then
        echo "Invalid index."
        return
    fi
    echo "Deleted entry #$param"
}


# Function to save changes and reload Nginx
save_and_reload() {
    # Generate allowlist with the correct format
    echo "# Auto-generated allowlist" > "$ALLOWLIST_FILE"
    
    # Read the database file line by line
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ "$line" =~ ^\s*# ]] || [[ -z "$line" ]]; then
            continue
        fi

        # Check if the line contains a '#' character
        if [[ "$line" == *"#"* ]]; then
            # If there's a '#' in the line, split the IP and comment
            ip=$(echo "$line" | cut -d '#' -f 1 | xargs)   # IP part (before #), remove any extra spaces
            comment=$(echo "$line" | cut -d '#' -f 2-)    # Comment part (after #), including the comment
            # Add the IP with the comment
            echo "    $ip 1; #$comment" >> "$ALLOWLIST_FILE"
        else
            # If no '#' in the line, the whole line is the IP
            ip=$(echo "$line" | xargs)  # IP part (whole line), remove any extra spaces
            # Add the IP with no comment
            echo "    $ip 1;" >> "$ALLOWLIST_FILE"
        fi
    done < "$DATABASE"

	cat "$ALLOWLIST_FILE"

    # Reload Nginx
    docker compose -f "$DOCKER_COMPOSE_FILE" exec "$DOCKER_COMPOSE_NGINX_SERVICE_NAME" nginx -s reload || {
        echo "Error: Could not reload Nginx. Is the container running?"
        return
    }
    echo "Nginx allowlist updated and reloaded."
    
}

show_running_ngnix_config(){
	docker compose -f "$DOCKER_COMPOSE_FILE" exec $DOCKER_COMPOSE_NGINX_SERVICE_NAME nginx -T
}





# Main menu loop
while true; do
    show_allowlist  # Always show the list before taking input

    echo "Choose an action:"
    echo "A - Add IP"
    echo "E # - Edit IP (#)"
    echo "D # - Delete IP (#)"
    echo "S - Save & Apply changes"
    echo "C - Show running ngnix config"
    echo "Q - Quit"
    
    read -rp "Enter command: " action param
    
    case "$action" in
        A|a) add_ip ;;
        E|e) edit_ip "$param" ;;
        D|d) delete_ip "$param" ;;
        S|s) save_and_reload ;;
        C|c) show_running_ngnix_config ;;
        Q|q) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid input, try again." ;;
    esac
    # Clear the param after operation
    param=""
done
