#!/usr/bin/env bash

source /root/.bashrc
function prop { key="${2}=" file="/root/.k8s/${1}" rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); [[ -z "$rslt" ]] && key="${2} = " && rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); rslt=$(echo "$rslt" | tr -d '\n' | tr -d '\r'); echo "$rslt"; }
cd /vagrant/tz-local/resource/ingress_nginx

NS=$1
if [[ "${NS}" == "" ]]; then
  NS=default
fi
k8s_project=$2
if [[ "${k8s_project}" == "" ]]; then
  k8s_project=$(prop 'project' 'project')
fi
k8s_domain=$3
if [[ "${k8s_domain}" == "" ]]; then
  k8s_domain=$(prop 'project' 'domain')
fi

#set -x
shopt -s expand_aliases
alias k="kubectl -n ${NS} --kubeconfig ~/.kube/config"

#kubectl delete ns ${NS}
kubectl create ns ${NS}

kubectl apply -f ingress-nginx-configmap.yaml -n ${NS}

cp -Rf nginx-ingress.yaml nginx-ingress.yaml_bak
sed -i "s|NS|${NS}|g" nginx-ingress.yaml_bak
sed -i "s/k8s_project/${k8s_project}/g" nginx-ingress.yaml_bak
sed -i "s/k8s_domain/${k8s_domain}/g" nginx-ingress.yaml_bak
k delete -f nginx-ingress.yaml_bak -n ${NS}
k delete ingress $(k get ingress nginx-test-tls -n ${NS}) -n ${NS}
k delete svc nginx -n ${NS}
k apply -f nginx-ingress.yaml_bak -n ${NS}
sleep 10
curl -v http://test.${NS}.${k8s_project}.${k8s_domain}
echo curl http://test.${NS}.${k8s_project}.${k8s_domain}
k delete -f nginx-ingress.yaml_bak

#### https ####
cp -Rf nginx-ingress-https.yaml nginx-ingress-https.yaml_bak
sed -i "s/NS/${NS}/g" nginx-ingress-https.yaml_bak
sed -i "s/k8s_project/${k8s_project}/g" nginx-ingress-https.yaml_bak
sed -i "s/k8s_domain/${k8s_domain}/g" nginx-ingress-https.yaml_bak
k delete -f nginx-ingress-https.yaml_bak -n ${NS}
k delete ingress nginx-test-tls -n ${NS}
k apply -f nginx-ingress-https.yaml_bak -n ${NS}
kubectl get csr -o name | xargs kubectl certificate approve
sleep 10
curl -v http://test.${NS}.${k8s_project}.${k8s_domain}
curl -L -f -v https://test.${NS}.${k8s_project}.${k8s_domain} || echo "Test connection failed, but continuing..."

exit 0
