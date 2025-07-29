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
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
APP_VERSION=4.0.13
#helm search repo nginx-ingress
helm uninstall ingress-nginx -n ${NS}
#--reuse-values
helm upgrade --debug --install ingress-nginx ingress-nginx/ingress-nginx \
  -f values.yaml --version ${APP_VERSION} -n ${NS}

# kubectl get -A ValidatingWebhookConfiguration ingress-nginx-admission
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission

sleep 60
DEVOPS_ELB=$(kubectl get svc | grep ingress-nginx-controller | grep LoadBalancer | head -n 1 | awk '{print $4}')
echo "####################################################################################"
echo " DEVOPS_ELB: ${DEVOPS_ELB}"
echo "####################################################################################"
if [[ "${DEVOPS_ELB}" == "" ]]; then
  echo "No elb! check nginx-ingress-controller with LoadBalancer type!"
  exit 1
fi
cp -Rf nginx-ingress.yaml nginx-ingress.yaml_bak
sed -i "s|NS|${NS}|g" nginx-ingress.yaml_bak
sed -i "s/k8s_project/${k8s_project}/g" nginx-ingress.yaml_bak
sed -i "s/k8s_domain/${k8s_domain}/g" nginx-ingress.yaml_bak
k delete -f nginx-ingress.yaml_bak
k delete ingress $(k get ingress nginx-test-tls)
k delete svc nginx
k apply -f nginx-ingress.yaml_bak
echo curl http://test.${NS}.${k8s_project}.${k8s_domain}
sleep 30
curl -v http://test.${NS}.${k8s_project}.${k8s_domain}
#k delete -f nginx-ingress.yaml_bak

#### https ####
helm repo add jetstack https://charts.jetstack.io
helm repo update

## Install using helm v3+
helm uninstall cert-manager -n cert-manager
k delete -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.crds.yaml
kubectl get customresourcedefinition | grep cert-manager | awk '{print $1}' | xargs -I {} kubectl delete customresourcedefinition {}
#k delete namespace cert-manager
k create namespace cert-manager
# Install needed CRDs
k apply --validate=false -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.0/cert-manager.crds.yaml
# --reuse-values
helm upgrade --debug --install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=false \
  --version v1.10.0

sleep 30

kubectl get CustomResourceDefinition | grep cert-manager
kubectl get all -n cert-manager

k get pods --namespace cert-manager
k delete -f letsencrypt-prod.yaml
k apply -f letsencrypt-prod.yaml

sleep 20

cp -Rf nginx-ingress-https.yaml nginx-ingress-https.yaml_bak
sed -i "s/NS/${NS}/g" nginx-ingress-https.yaml_bak
sed -i "s/k8s_project/${k8s_project}/g" nginx-ingress-https.yaml_bak
sed -i "s/k8s_domain/${k8s_domain}/g" nginx-ingress-https.yaml_bak
#k delete -f nginx-ingress-https.yaml_bak -n ${NS}
#k delete ingress nginx-test-tls -n ${NS}
k apply -f nginx-ingress-https.yaml_bak -n ${NS}
kubectl get csr -o name | xargs kubectl certificate approve
echo curl http://test.${NS}.${k8s_project}.${k8s_domain}
sleep 10
curl -v http://test.${NS}.${k8s_project}.${k8s_domain}
echo curl https://test.${NS}.${k8s_project}.${k8s_domain}
curl -v https://test.${NS}.${k8s_project}.${k8s_domain}

kubectl get certificate -n ${NS}
kubectl describe certificate nginx-test-tls -n ${NS}

kubectl get secrets --all-namespaces | grep nginx-test-tls
kubectl get certificates --all-namespaces | grep nginx-test-tls

check_host=`cat /etc/hosts | grep 'jenkins'`
if [[ "${check_host}" == "" ]]; then
LB=`kubectl get svc | grep ingress-nginx-controller | grep LoadBalancer | awk '{print $4}'`
cat <<EOF >> /etc/hosts
${LB}   test.default.topzone-k8s.topzone.me consul.default.topzone-k8s.topzone.me vault.default.topzone-k8s.topzone.me
${LB}   consul-server.default.topzone-k8s.topzone.me argocd.default.topzone-k8s.topzone.me
${LB}   jenkins.default.topzone-k8s.topzone.me harbor.harbor.topzone-k8s.topzone.me
${LB}   grafana.default.topzone-k8s.topzone.me prometheus.default.topzone-k8s.topzone.me alertmanager.default.topzone-k8s.topzone.me
EOF
fi

##PROJECTS=(default)
#PROJECTS=(default devops devops-dev argocd consul vault)
#for item in "${PROJECTS[@]}"; do
#  if [[ "${item}" != "NAME" ]]; then
#    echo "====================="
#    echo ${item}
#    bash /vagrant/tz-local/resource/ingress_nginx/update.sh ${item} ${k8s_project} ${k8s_domain}
#  fi
#done

bash /vagrant/tz-local/resource/ingress_nginx/self-signed/install.sh

exit 0


calicoctl patch BGPConfig default --patch '{"spec": {"serviceLoadBalancerIPs":
[{"cidr": "10.11.0.0/16"},{"cidr":"10.1.5.0/24"}]}}'


apiVersion: crd.projectcalico.org/v1
kind: BGPConfiguration
metadata:
  annotations:
    projectcalico.org/metadata: '{"uid":"81fcb6c1-fcd8-4c14-87ae-8685d3cfab48","creationTimestamp":"2023-04-14T03:21:22Z"}'
  creationTimestamp: "2023-04-14T03:21:22Z"
  generation: 1
  name: default
  resourceVersion: "153808"
  uid: 81fcb6c1-fcd8-4c14-87ae-8685d3cfab48
spec:
  asNumber: 64512
  listenPort: 179
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: false
  serviceClusterIPs:
  - cidr: 192.168.0.0/12
