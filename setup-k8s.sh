#!/bin/bash -e

#!/bin/bash

# Default values
controller=""
workers=()
docker_hosts=""
env_vars=""

# Function to display usage message
function usage() {
  echo "Usage: $0 -c <user@ip[:port]> [-w <user@ip[:port],...>] [-e <key=value> ...]"
  echo "Options:"
  echo "  -c, --controller <user@ip[:port]>   Specify the SSH connection pattern for the controller (required)"
  echo "  -w, --workers <user@ip[:port],...>  Specify the SSH connection patterns for the workers (optional, comma-separated)"
  echo "  -e, --extra-vars <key=value>            Specify additional environment variables (optional, multiple can be provided)"
  echo "  -h, --help                              Display this help message"
}

# Parse command line arguments
while getopts ":c:w:e:h" opt; do
  case ${opt} in
    c | --controller)
      controller=$OPTARG
      docker_hosts+="$OPTARG,"
      ;;
    w | --workers)
      docker_hosts+="$OPTARG,"
      IFS=',' read -ra worker_pattern <<< "$OPTARG"
      for pattern in "${worker_pattern[@]}"; do
        workers+=("$pattern")
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
if [[ -z $controller ]]; then
  echo "Error: at least argument -c or --controller is required." >&2
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

# Extract for controller
controller_info=($(parse_ssh_connection "$controller"))

# Setup passwordlesss for whole cluster
cluster+=("$controller")
cluster+=("${workers[@]}")
./setup-docker.sh -m "${docker_hosts%,}" "${env_vars}"

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
    index=1
    for worker in "${workers[@]}"; do
        worker_info=($(parse_ssh_connection "$worker"))
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
    index=1
    for worker in "${workers[@]}"; do
        cat <<EOF
        worker-$index: *worker-$index
EOF
    index=$(( index + 1 ))
    done
)"
inventory_file=${inventory_file:-/tmp/inventory-k8s.yaml}
cat <<EOF | tee $inventory_file
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
# Ansible playbook with generated inventory file
# set -x
ANSIBLE_ROLES_PATH=./roles \
ANSIBLE_INVENTORY_ENABLED=yaml \
ansible-playbook -vv \
${env_vars} \
-i $inventory_file ./setup-k8s.yaml \
| tee /tmp/setup-k8s-$(date +'%Y-%m-%d_%H-%M-%S').log