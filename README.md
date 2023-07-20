Setup Kubernetes with Ansible Playbook

```
Usage: ./setup-k8s.sh -c <user@ip[:port]> [-w <user@ip[:port],...>] [-e <key=value> ...]
Options:
  -c, --controller <user@ip[:port]>   Specify the SSH connection pattern for the controller (required)
  -w, --workers <user@ip[:port],...>  Specify the SSH connection patterns for the workers (optional, comma-separated)
  -e, --extra-vars <key=value>            Specify additional environment variables (optional, multiple can be provided)
  -h, --help                              Display this help message
```