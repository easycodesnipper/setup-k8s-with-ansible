#!/bin/bash -e

#!/bin/bash

# Default values
machines=()
env_vars=""

# Function to display usage message
function usage() {
  echo "Usage: $0 -m <user@ip[:port]>[<user@ip[:port],...>] [-e <key=value> ...]"
  echo "Options:"
  echo "  -m, --machine <user@ip[:port],...>      Specify the SSH connection patterns for the machine(s) (required at least one, multiple can be provided with comma-separated)"
  echo "  -e, --extra-vars <key=value>            Specify additional environment variables (optional, multiple can be provided)"
  echo "  -h, --help                              Display this help message"
}

# Parse command line arguments
while getopts ":m:e:h" opt; do
  case ${opt} in
    m | --machine)
      IFS=',' read -ra ssh_pattern <<< "$OPTARG"
      for pattern in "${ssh_pattern[@]}"; do
        machines+=("$pattern")
      done
      ;;
    e | --extra-vars)
      env_vars+=" -e $OPTARG"
      ;;
    h | --help)
      usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      exit 1
      ;;
  esac
done

# Check for required arguments
if [[ ${#machines[@]} == 0 ]]; then
  echo "Error: at least one machine -m or --machine is required." >&2
  usage
  exit 1
fi

# Function to parse user,ip,port from the SSH connection pattern
function parse_ssh_connection() {
  local pattern=$1
  IFS='@:' read -ra parts <<< "$pattern"
  local user=${parts[0]}
  local ip=${parts[1]}
  local port=${parts[2]:-22}    # Default to port 22 if not specified
  local info=("$user" "$ip" "${port:-22}")
  echo "${info[@]}"
}

# Setup passwordlesss for whole machines
./setup-passwordless.sh "${machines[@]}"

# Check if Ansible is installed
ansible --version >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Ansible is not installed. Please install Ansible before running this script."
    exit 1
fi

# Generate machine(s) block and reference block
cluster_hosts_block="$(
    index=1
    for machine in "${machines[@]}"; do
        machine_info=($(parse_ssh_connection "$machine"))
        cat <<EOF
        host-$index: 
          ansible_user: "${machine_info[0]}"
          ansible_host: "${machine_info[1]}"
          ansible_port: "${machine_info[2]}"  
EOF
        index=$(( index + 1 ))
    done
)"
inventory_file=${inventory_file:-/tmp/inventory-docker.yaml}
cat <<EOF | tee $inventory_file
all:
  children:
    cluster_hosts:
      hosts:
$cluster_hosts_block
EOF
# Ansible playbook with generated inventory file
# set -x
ANSIBLE_ROLES_PATH=./roles \
ANSIBLE_INVENTORY_ENABLED=yaml \
ansible-playbook -vv \
${env_vars} \
-i $inventory_file ./setup-docker.yaml \
| tee /tmp/setup-docker-$(date +'%Y-%m-%d_%H-%M-%S').log