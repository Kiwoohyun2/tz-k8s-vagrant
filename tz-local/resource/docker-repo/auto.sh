#!/usr/bin/env bash

cd /vagrant/tz-local/resource/docker-repo

k8s_project=$(prop 'project' 'project')
k8s_domain=$(prop 'project' 'domain')
admin_password=$(prop 'project' 'admin_password')
dockerhub_id=$(prop 'project' 'dockerhub_id')
dockerhub_password=$(prop 'project' 'dockerhub_password')
docker_url=$(prop 'project' 'docker_url')

kubectl delete -f https://raw.githubusercontent.com/alexellis/tz-registrykey/master/manifest.yaml
kubectl apply -f https://raw.githubusercontent.com/alexellis/tz-registrykey/master/manifest.yaml

export DOCKER_USERNAME=$dockerhub_id
export PW=$dockerhub_password
export EMAIL=topzone8713@gmail.com

kubectl delete secret tz-registrykey -n kube-system
kubectl create secret docker-registry tz-registrykey \
  --namespace kube-system \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=$DOCKER_USERNAME \
  --docker-password=$PW \
  --docker-email=$EMAIL

#kubectl delete secret tz-registrykey -n jenkins
#kubectl create secret docker-registry tz-registrykey \
#  --namespace jenkins \
#  --docker-server=https://nexus.okestro-k8s.okestro.me:5000/v2/ \
#  --docker-username=$DOCKER_USERNAME \
#  --docker-password=$PW \
#  --docker-email=$EMAIL

#  --docker-server=https://nexus.okestro-k8s.okestro.me:5000/v2/ \
#kubectl get secret tz-registrykey --output=yaml

kubectl delete -f clusterPullSecret.yaml
kubectl apply -f clusterPullSecret.yaml

#kubectl annotate ns jenkins alexellis.io/tz-registrykey.ignore=0 --overwrite
#kubectl annotate ns jenkins alexellis.io/tz-registrykey.ignore=1
#kubectl annotate ns devops-dev alexellis.io/tz-registrykey.ignore=0 --overwrite
