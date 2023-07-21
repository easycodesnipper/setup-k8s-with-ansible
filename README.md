# Setup Kubernetes with Ansible Playbook

```shell
Usage: ./setup-k8s.sh -c <user@ip[:port]> [-w <user@ip[:port],...>] [-e <key=value> ...]
Options:
  -c, --controller <user@ip[:port]>   Specify the SSH connection pattern for the controller (required)
  -w, --workers <user@ip[:port],...>  Specify the SSH connection patterns for the workers (optional, comma-separated)
  -e, --extra-vars <key=value>            Specify additional environment variables (optional, multiple can be provided)
  -h, --help                              Display this help message
```

### If your network is behind a proxy, usage as below:
e.g: Cluster = 1 controller + 2 workers 
```shell
./setup-k8s.sh -c ubuntu@192.168.3.51:22 -w ubuntu@192.168.3.52,centos@192.168.3.53:22 -e http_proxy=http://192.168.3.200:11080 -e https_proxy=http://192.168.3.200:11080
```

### If your network is blocked to access Docker or Google Container Registry(GCR), a mirror can be used as follows:
### *BTW, fuck [GFW](https://zh.wikipedia.org/wiki/%E9%98%B2%E7%81%AB%E9%95%BF%E5%9F%8E)*
e.g.: Cluster = 1 controller + 2 workers
```shell
./setup-k8s.sh -c ubuntu@192.168.3.51:22 -w ubuntu@192.168.3.52,centos@192.168.3.53:22 -e mirror=Aliyun
```

### If you prefer to reinstall Docker or Kubernetes, you can add below options:
```shell
./setup-k8s.sh ... -e docker_reset=true -e k8s_reset=true
```

### If you prefer to deploy Dashboard after Kubernetes installed, another option you can append as below:
```shell
./setup-k8s.sh ... -e k8s_dashboard_enabled=true

# Open Browser with URL https://<your node ip>:30443

# Execute below command to get admin user access token for login
kubectl get secret ${ADMIN_USERNAME:-admin} -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d
```
