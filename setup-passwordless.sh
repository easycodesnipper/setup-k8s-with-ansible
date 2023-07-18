#!/bin/bash -e

# Function to display usage information
function usage() {
    echo "Usage: $0 <user@ip[:port]> [<user@ip[:port]> ...]"
}

# Check if required arguments are provided
if [[ $# -lt 1 ]]; then
    echo "Error: Remote server arguments are missing."
    usage
    exit 1
fi

# Iterate over each remote server argument
for remote_server in "$@"; do
    # Extract user, IP and port from the remote server argument
    user_ip_port="$remote_server"
    user="$(echo "$user_ip_port" | cut -d'@' -f1)"
    ip_port="$(echo "$user_ip_port" | cut -d'@' -f2)"
    ip=""
    port=""
    if [[ $ip_port == *":"* ]]; then
        ip="$(echo "$ip_port" | cut -d':' -f1)"
        port="$(echo "$ip_port" | cut -d':' -f2)"
    else
        ip="$ip_port"
        port=22
    fi

    echo "Copying public key to remote server: $remote_server"
    ssh-copy-id -p "$port" "$user@$ip"
    # Check if ssh-copy-id was successful
    if [[ $? -eq 0 ]]; then
        echo "SSH passwordless setup completed successfully for $remote_server."
        ssh -p "$port" "$user@$ip" "sudo -S grep -q \"$user\" /etc/sudoers || echo \"$user ALL=(ALL) NOPASSWD:ALL\" | sudo tee -a /etc/sudoers"
        if [[ $? -eq 0 ]]; then
            echo "Adding user $user to sudoers group with passwordless completed successfully for $remote_server."
        fi
    else
        echo "Failed to set up SSH passwordless login for $remote_server."
    fi
done
