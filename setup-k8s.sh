#!/bin/bash -e

# Function to display usage information
function usage() {
    echo "Usage: $0 --controller=<user@ip[:port]> [--workers=<user@ip[:port]>,[<user@ip[:port]> ...]]"
}

# Parse command line arguments
controller=""
workers=""
envs=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --controller=*)
            controller="${1#*=}"
            shift
            ;;
        --workers=*)
            workers="${1#*=}"
            shift
            ;;
        --env=*)
            IFS=',' read -ra env_array <<< "${1#*=}"
            for item in "${env_array[@]}"; do
                envs+=("$item")
            done
            shift
            ;;
        *)
            echo "Invalid options"
            usage
            exit 1
            ;;
    esac
done

# Check if required arguments are provided
if [[ -z $controller ]]; then
    echo "Error: At least one controller is required."
    usage
    exit 1
fi

# Check if Ansible is installed
function precheck() {
    ansible --version >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Ansible is not installed. Please install Ansible before running this script."
        exit 1
    fi
}

# Extract username, IP address, and port
function extract_info() {
    local user_ip_port="$1"
    local user="$(echo "$user_ip_port" | cut -d'@' -f1)"
    local ip_port="$(echo "$user_ip_port" | cut -d'@' -f2)"
    local ip=""
    local port=""
    if [[ $ip_port == *":"* ]]; then
        ip="$(echo "$ip_port" | cut -d':' -f1)"
        port="$(echo "$ip_port" | cut -d':' -f2)"
    else
        ip="$ip_port"
    fi
    local info=("$user" "$ip" "${port:-22}")
    echo "${info[@]}"
}

# Extract for controller
controller_info=($(extract_info "$controller"))

# Workers array
IFS=',' read -ra worker_array <<< "$workers"

# Setup passwordlesss for whole cluster
cluster+=("$controller")
cluster+=("${worker_array[@]}")
./setup-passwordless.sh "${cluster[@]}"

# Generate controller block and reference block
controller_block="$(
    cat <<EOF
        controller: &controller
          ansible_user: "${controller_info[0]}"
          ansible_host: "${controller_info[1]}"
          ansible_port: "${controller_info[2]}"
EOF
)"
controller_ref_block="$(
    cat <<EOF
        controller: *controller
EOF
)"

# Generate workers block and reference block
workers_block="$(
    index=0
    for worker in "${worker_array[@]}"; do
        worker_info=($(extract_info "$worker"))
        cat <<EOF
        worker-$index: &worker-$index
          ansible_user: "${worker_info[0]}"
          ansible_host: "${worker_info[1]}"
          ansible_port: "${worker_info[2]}"  
EOF
        index=$(( index + 1 ))
    done
)"
worker_ref_block="$(
    index=0
    for worker in "${worker_array[@]}"; do
        cat <<EOF
        worker-$index: *worker-$index
EOF
    index=$(( index + 1 ))
    done
)"

function gen_ansible_env() {
    env_string=""
    for item in "${envs[@]}"; do
        env_string+=" -e $item"
    done
    echo "$env_string"
}

# Ansible playbook with generated inventory file
ANSIBLE_ROLES_PATH=./roles \
ANSIBLE_INVENTORY_ENABLED=yaml \
ansible-playbook -vv \
$(gen_ansible_env) \
-i <(cat <<EOF
all:
  children:
    cluster_hosts:
      hosts:
$controller_block
$workers_block
    controller_hosts:
      hosts: 
$controller_ref_block
    worker_hosts:
      hosts:
$worker_ref_block
EOF
) ./setup-k8s.yaml | tee /tmp/setup-k8s-$(date +'%Y-%m-%d_%H-%M-%S').log