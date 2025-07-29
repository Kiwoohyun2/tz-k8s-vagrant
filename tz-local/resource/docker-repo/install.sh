#!/usr/bin/env bash

source /root/.bashrc
function prop { key="${2}=" file="/root/.k8s/${1}" rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); [[ -z "$rslt" ]] && key="${2} = " && rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); rslt=$(echo "$rslt" | tr -d '\n' | tr -d '\r'); echo "$rslt"; }
cd /vagrant/tz-local/resource/docker-repo

#set -x
shopt -s expand_aliases
alias k='kubectl'

k8s_project=$(prop 'project' 'project')
k8s_domain=$(prop 'project' 'domain')
dockerhub_id=$(prop 'project' 'dockerhub_id')
dockerhub_password=$(prop 'project' 'dockerhub_password')
docker_url=$(prop 'project' 'docker_url')

#kubectl describe cm/coredns -n kube-system > coredns.yqml
#kubectl edit cm/coredns -n kube-system
#
#data:
#  Corefile: |
#    .:53 {
#        errors {
#        }
#        health {
#            lameduck 5s
#        }
#        ready
#        ~~~~
#    }
#    harbor.harbor.topzone-k8s.topzone.me:53 {
#        hosts {
#            192.168.0.200    harbor.harbor.topzone-k8s.topzone.me
#        }
#    }

#kubectl -n kube-system rollout restart deployment coredns

# apt-get update && apt-get install dnsutils -y
# nslookup harbor.harbor.topzone-k8s.topzone.me

apt-get update -y
apt-get -y install docker.io jq
#mkdir -p ~/.docker
#docker login -u="${dockerhub_id}" -p="${dockerhub_password}"

mkdir -p /root/.docker

#cat <<EOF > /etc/docker/daemon.json
#{
#    "insecure-registries": ["harbor.harbor.topzone-k8s.topzone.me"]
#}
#EOF
#service docker restart
#echo "Harbor12345" | docker login harbor.harbor.topzone-k8s.topzone.me -u admin --password-stdin

cp -Rf /vagrant/resources/config.json /root/.docker/config.json
chown -Rf topzone:topzone /root/.docker

kubectl delete secret tz-registrykey -n kube-system
kubectl create secret generic tz-registrykey \
    --from-file=.dockerconfigjson=/root/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson -n kube-system

#PROJECTS=(default)
PROJECTS=(argocd consul harbor jenkins default devops devops-dev monitoring vault)
for item in "${PROJECTS[@]}"; do
  if [[ "${item}" != "NAME" ]]; then
    echo "===================== ${item}"
    kubectl create namespace ${item}
    kubectl delete secret tz-registrykey -n ${item}
    kubectl create secret generic tz-registrykey \
      -n ${item} \
      --from-file=.dockerconfigjson=/root/.docker/config.json \
      --type=kubernetes.io/dockerconfigjson
  fi
done

kubectl get secret tz-registrykey --output=yaml
kubectl get secret tz-registrykey -n vault --output=yaml

kubectl get secret tz-registrykey --output="jsonpath={.data.\.dockerconfigjson}" | base64 --decode

exit 0


sudo vi /etc/containerd/config.toml

    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://registry-1.docker.io", "https://harbor.harbor.topzone-k8s.topzone.me"]

    [plugins."io.containerd.grpc.v1.cri".registry.configs]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."harbor.harbor.topzone-k8s.topzone.me".auth]
          username = "admin"
          password = "Harbor12345"
        [plugins."io.containerd.grpc.v1.cri".registry.configs."harbor.harbor.topzone-k8s.topzone.me".tls]
          insecure_skip_verify = true
