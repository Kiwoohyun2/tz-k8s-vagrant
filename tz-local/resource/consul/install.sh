#!/usr/bin/env bash

source /root/.bashrc
function prop { key="${2}=" file="/root/.k8s/${1}" rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); [[ -z "$rslt" ]] && key="${2} = " && rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); rslt=$(echo "$rslt" | tr -d '\n' | tr -d '\r'); echo "$rslt"; }

#bash /vagrant/tz-local/resource/consul/install.sh
cd /vagrant/tz-local/resource/consul

#set -x
shopt -s expand_aliases
alias k='kubectl -n consul'

k8s_project=$(prop 'project' 'project')
k8s_domain=$(prop 'project' 'domain')
basic_password=$(prop 'project' 'basic_password')
NS=consul

helm repo add hashicorp https://helm.releases.hashicorp.com
helm search repo hashicorp/consul

helm uninstall consul -n consul
k delete PersistentVolumeClaim data-consul-consul-server-0
kubectl delete namespace consul

#k delete namespace consul
k create namespace consul
cp values.yaml values.yaml_bak
helm uninstall consul -n consul
#--reuse-values
helm upgrade --debug --install consul hashicorp/consul -f /vagrant/tz-local/resource/consul/values.yaml_bak -n consul --version 1.0.2

cp -Rf consul-ingress.yaml consul-ingress.yaml_bak
sed -i "s/k8s_project/${k8s_project}/g" consul-ingress.yaml_bak
sed -i "s/k8s_domain/${k8s_domain}/g" consul-ingress.yaml_bak
sed -i "s|NS|${NS}|g" consul-ingress.yaml_bak
k delete -f consul-ingress.yaml_bak -n consul
k apply -f consul-ingress.yaml_bak -n consul

#kubectl get certificate -n consul
#kubectl describe certificate ingress-consul-tls -n consul

#kubectl -n consul apply -f mesh/upgrade.yaml

#k delete -f /vagrant/tz-local/resource/consul/consul.yaml -n consul
#k apply -f /vagrant/tz-local/resource/consul/consul.yaml -n consul
#k get pod/tz-consul-deployment-78597cd9c5-vsbg4 -o yaml > a.yaml

#k create -f /vagrant/tz-local/resource/consul/counting.yaml -n consul
#k create -f /vagrant/tz-local/resource/consul/dashboard.yaml -n consul

sleep 60

export CONSUL_HTTP_ADDR="https://consul.default.${k8s_project}.${k8s_domain}"
echo https://$CONSUL_HTTP_ADDR

wget --no-check-certificate https://releases.hashicorp.com/consul/1.8.4/consul_1.8.4_linux_amd64.zip && \
    unzip consul_1.8.4_linux_amd64.zip && \
    rm -Rf consul_1.8.4_linux_amd64.zip && \
    sudo mv consul /usr/local/bin/ && \
    sudo chmod +x /usr/local/bin/consul

consul members

exit 0

