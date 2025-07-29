#!/usr/bin/env bash

#https://kubesphere.io/docs/devops-user-guide/how-to-integrate/harbor/

source /root/.bashrc
function prop { key="${2}=" file="/root/.k8s/${1}" rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); [[ -z "$rslt" ]] && key="${2} = " && rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); rslt=$(echo "$rslt" | tr -d '\n' | tr -d '\r'); echo "$rslt"; }
#bash /vagrant/tz-local/resource/harbor/install.sh
cd /vagrant/tz-local/resource/harbor

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

k8s_project=$(prop 'project' 'project')
k8s_domain=$(prop 'project' 'domain')
admin_password=$(prop 'project' 'admin_password')
basic_password=$(prop 'project' 'basic_password')
NS=harbor

kubectl delete ns ${NS}
kubectl create ns ${NS}
helm repo add harbor https://helm.goharbor.io
helm uninstall harbor-release -n ${NS}
#helm show values harbor/harbor > values.yaml
cp -Rf values.yaml values.yaml_bak
sed -ie "s|k8s_project|${k8s_project}|g" values.yaml_bak
sed -ie "s|k8s_domain|${k8s_domain}|g" values.yaml_bak
sed -ie "s|NS|${NS}|g" values.yaml_bak
#--reuse-values
helm upgrade -n ${NS} --debug --install --reuse-values harbor-release harbor/harbor -f values.yaml_bak

sleep 300

#cp -Rf harbor-ingress.yaml harbor-ingress.yaml_bak
#sed -ie "s/k8s_project/${k8s_project}/g" harbor-ingress.yaml_bak
#sed -ie "s/k8s_domain/${k8s_domain}/g" harbor-ingress.yaml_bak
#sed -ie "s|NS|devops|g" harbor-ingress.yaml_bak
#kubectl delete -f harbor-ingress.yaml_bak
#kubectl apply -f harbor-ingress.yaml_bak

#new project: ks-devops-harbor
#NEW ROBOT ACCOUNT in Robot Accounts.
# robot account: robot-test
# robot$ks-devops-harbor+robot-test / yhPjAlYZNceJItf1xKGK11Gg2beQfacd

#      tolerations: []
#    enabled: false
#  local_registry: '172.20.247.60:80'  # Add a new field of Harbor address to this line.
#  logging:
#    enabled: false

#cat <<EOF > /etc/docker/daemon.json
#{
#  "insecure-registries":["harbor.harbor.okestro-k8s.okestro.me"]
#}
#EOF
#
#echo "Harbor12345" | docker login harbor.harbor.okestro-k8s.okestro.me -u admin --password-stdin
#
#kubectl delete secret harbor-registry-secret -n jenkins
#kubectl create secret generic harbor-registry-secret \
#    --from-file=.dockerconfigjson=/root/.docker/config.json \
#    --type=kubernetes.io/dockerconfigjson -n jenkins

exit 0
