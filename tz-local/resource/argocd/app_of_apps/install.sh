#!/usr/bin/env bash

source /root/.bashrc
function prop { key="${2}=" file="/root/.k8s/${1}" rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); [[ -z "$rslt" ]] && key="${2} = " && rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); rslt=$(echo "$rslt" | tr -d '\n' | tr -d '\r'); echo "$rslt"; }
cd /vagrant/tz-local/resource/argocd/app_of_apps

#set -x
shopt -s expand_aliases

git clone https://github.com/Kiwoohyun2/demo-app.git

cd demo-app

kubectl apply -n argocd -f demo-app/argocd/application.yml
kubectl delete -n argocd -f demo-app/argocd/application.yml

helm repo add argo https://argoproj.github.io/argo-helm
helm install -n argocd argocd-demo argo/argo-cd -f demo-app/values.yaml

kubectl -n argocd describe application/devops-admin








exit 0


