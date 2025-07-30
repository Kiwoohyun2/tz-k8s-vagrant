#!/usr/bin/env bash

source /root/.bashrc
function prop { key="${2}=" file="/root/.k8s/${1}" rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); [[ -z "$rslt" ]] && key="${2} = " && rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); rslt=$(echo "$rslt" | tr -d '\n' | tr -d '\r'); echo "$rslt"; }
#bash /vagrant/tz-local/resource/argocd/helm/install.sh
cd /vagrant/tz-local/resource/argocd/helm

#set -x
shopt -s expand_aliases

k8s_project=$(prop 'project' 'project')
k8s_domain=$(prop 'project' 'domain')
admin_password=$(prop 'project' 'admin_password')
github_id=$(prop 'project' 'github_id')
github_token=$(prop 'project' 'github_token')
basic_password=$(prop 'project' 'basic_password')
VAULT_TOKEN=$(prop 'project' 'vault')

alias k='kubectl --kubeconfig ~/.kube/config'
#alias k="kubectl --kubeconfig ~/.kube/kubeconfig_${k8s_project}"

#k delete namespace argocd
k create namespace argocd

#################################################################################
# 1) install argocd
#################################################################################
helm repo add argo https://argoproj.github.io/argo-helm
helm uninstall argocd argo/argo-cd -n argocd

#  AVP_AUTH_TYPE: azhz    k8s
#  AVP_K8S_MOUNT_PATH: YXV0aC9rdWJlcm5ldGVz   auth/kubernetes
#  AVP_K8S_ROLE: azhz   k8s
#  AVP_TYPE: dmF1bHQ=   vault
#  VAULT_ADDR: aHR0cDovL3ZhdWx0LnZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsOjgyMDA=     http://vault.vault.svc.cluster.local:8200
kubectl -n argocd delete -f argocd-installation/argocd-vault-plugin-credentials.yaml
kubectl -n argocd apply -f argocd-installation/argocd-vault-plugin-credentials.yaml
#--reuse-values
helm upgrade --debug --install argocd argo/argo-cd \
  -n argocd -f argocd-installation/argocd-helm-values.yaml --version 5.20.4

#  AVP_AUTH_TYPE: azhz    k8s
#  AVP_K8S_MOUNT_PATH: YXV0aC9rdWJlcm5ldGVz   auth/kubernetes
#  AVP_K8S_ROLE: azhz   k8s
#  AVP_TYPE: dmF1bHQ=   vault
#  VAULT_ADDR: aHR0cDovL3ZhdWx0LnZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsOjgyMDA=     http://vault.vault.svc.cluster.local:8200
kubectl -n argocd delete -f argocd-installation/argocd-vault-plugin-cmp.yaml
kubectl -n argocd apply -f argocd-installation/argocd-vault-plugin-cmp.yaml

k patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
sleep 120
TMP_PASSWORD=$(k -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "############################################"
echo "TMP_PASSWORD: ${TMP_PASSWORD}"
echo "############################################"

VERSION=$(curl -L -f --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' || echo "v2.8.4")
sudo curl -L -f -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64 || sudo wget --no-check-certificate -O /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
sudo chmod +x /usr/local/bin/argocd
#brew tap argoproj/tap
#brew install argoproj/tap/argocd

argocd login `k get service -n argocd | grep -w "argocd-server " | awk '{print $4}'` --username admin --password ${TMP_PASSWORD} --insecure
argocd account update-password --account admin --current-password ${TMP_PASSWORD} --new-password ${admin_password}

#TMP_PASSWORD="${admin_password}"
#argocd login argocd.default.okestro-k8s.okestro.me:14444 --username admin --password ${TMP_PASSWORD} --insecure

# basic auth
#https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/
#https://kubernetes.github.io/ingress-nginx/examples/auth/basic/
#echo ${basic_password} | htpasswd -i -n admin > auth
#k create secret generic basic-auth-argocd --from-file=auth -n argocd
#k get secret basic-auth-argocd -o yaml -n argocd
#rm -Rf auth

cp -Rf ingress-argocd.yaml ingress-argocd.yaml_bak
sed -i "s/k8s_project/${k8s_project}/g" ingress-argocd.yaml_bak
sed -i "s/k8s_domain/${k8s_domain}/g" ingress-argocd.yaml_bak
k delete -f ingress-argocd.yaml_bak -n argocd
k apply -f ingress-argocd.yaml_bak -n argocd

#k patch deploy/argocd-server -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n argocd
#k patch deploy/argocd-applicationset-controller -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n argocd
#k patch deploy/argocd-redis -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n argocd
#k patch deploy/argocd-notifications-controller -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n argocd
#k patch deploy/argocd-repo-server -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n argocd
#k patch deploy/argocd-dex-server -p '{"spec": {"template": {"spec": {"nodeSelector": {"team": "devops", "environment": "prod"}}}}}' -n argocd
#k patch deploy/argocd-redis -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": "tz-registrykey"}]}}}}' -n argocd

argocd login `k get service -n argocd | grep argocd-server | awk '{print $4}' | head -n 1` --username admin --password ${admin_password} --insecure
argocd repo add https://github.com/${github_id}/tz-argocd-repo \
  --username ${github_id} --password ${github_token}

kubectl config get-contexts
#CURRENT   NAME             CLUSTER          AUTHINFO         NAMESPACE
#          okestro-k8s   okestro-k8s   okestro-k8s
#project=`kubectl config get-contexts | tail -n 1 | awk '{print $3}'`
#argocd cluster add --yes ${project}

bash /vagrant/tz-local/resource/argocd/update.sh
bash /vagrant/tz-local/resource/argocd/update.sh

#################################################################################
# 2) integrate with vault
#################################################################################
export VAULT_ADDR="http://vault.default.${k8s_project}.${k8s_domain}"
echo "VAULT_ADDR: ${VAULT_ADDR}"
vault login ${VAULT_TOKEN}
vault auth enable kubernetes

cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-repo-server
subjects:
  - kind: ServiceAccount
    name: argocd-repo-server
    namespace: argocd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-repo-server
EOF

# Prepare kube api server data
cat <<EOF | kubectl -n argocd apply -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-repo-server
  annotations:
    kubernetes.io/service-account.name: "argocd-repo-server"
type: kubernetes.io/service-account-token
EOF

export SECRET_NAME="argocd-repo-server"
export TR_ACCOUNT_TOKEN="$(kubectl -n argocd get secret ${SECRET_NAME} -o go-template='{{ .data.token }}' | base64 --decode)"
export K8S_API_SERVER="$(kubectl -n vault config view --raw -o go-template="{{ range .clusters }}{{ index .cluster \"server\" }}{{ end }}")"
export K8S_CACERT="$(kubectl -n vault config view --raw -o go-template="{{ range .clusters }}{{ index .cluster \"certificate-authority-data\" }}{{ end }}" | base64 --decode)"
echo "SECRET_NAME: ${SECRET_NAME}"
echo "TR_ACCOUNT_TOKEN: ${TR_ACCOUNT_TOKEN}"
echo "K8S_API_SERVER: ${K8S_API_SERVER}"
echo "K8S_CACERT: ${K8S_CACERT}"

# Send kube config to vault
vault write auth/kubernetes/config \
  kubernetes_host="${K8S_API_SERVER}" \
  kubernetes_ca_cert="${K8S_CACERT}" \
  token_reviewer_jwt="${TR_ACCOUNT_TOKEN}"

vault read auth/kubernetes/config

vault policy write argocd - <<EOF
path "secret/*" {
  capabilities = ["list", "read"]
}
EOF

vault write auth/kubernetes/role/argocd \
  bound_service_account_names=argocd-repo-server,devops-prod-svcaccount \
  bound_service_account_namespaces=* \
  policies=default,argocd ttl=15m

#################################################################################
# 3) verify access to vault from argocd-repo-server
#################################################################################

#kubectl -n vault port-forward svc/vault 8200:8200 &
#curl -v localhost:8200
#
#curl --request POST \
# --data '{"jwt": "'${TR_ACCOUNT_TOKEN}'", "role": "argocd"}' \
#   http://localhost:8200/v1/auth/kubernetes/login

#################################################################################
# 4) add demo app into arogocd with vault
#################################################################################
argocd app list
argocd app delete devops-tz-demo-app -y
argocd app create devops-tz-demo-app \
    --project devops \
    --repo https://github.com/${github_id}/tz-argocd-repo.git \
    --path devops-tz-demo-app/prod --dest-namespace devops \
    --dest-server https://kubernetes.default.svc \
    --directory-recurse --upsert --grpc-web --sync-policy automated

vault kv put secret/devops-prod/dbinfo name=123 passwod=456 ttl=789
vault kv get secret/devops-prod/dbinfo

kubectl delete -f demo/demo-application.yaml
kubectl apply -f demo/demo-application.yaml
kubectl apply -f demo/svcaccount.yaml

#kubectl delete -f demo/demo-application-dev.yaml
#kubectl apply -f demo/demo-application-dev.yaml

#kubectl -n devops apply -f demo/dev/secret.yaml
#kubectl -n devops apply -f demo/dev/deployment.yaml

argocd app sync devops-tz-demo-app

#################################################################################
# 5) apply vault's change into app
#################################################################################
vault kv put secret/devops-prod/dbinfo name=a123 passwod=a456 ttl=a789
vault kv get secret/devops-prod/dbinfo

argocd app get argocd/devops-tz-demo-app --hard-refresh
kubectl get secret devops-tz-demo-app-secret -o yaml -n devops
echo 'MTIz' | base64 -d
kubectl rollout restart deployment devops-demo-argo-vault -n devops

curl -L -f https://argo-vault.devops.okestro-k8s.okestro.me/index || echo "Argo vault connection test failed, but continuing..."

exit 0

# Installing locally
#On Linux or macOS via Curl
curl -L -f -Lo argocd-vault-plugin https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v1.13.1/argocd-vault-plugin_1.13.1_linux_arm64 || wget --no-check-certificate -O argocd-vault-plugin https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v1.13.1/argocd-vault-plugin_1.13.1_linux_arm64
chmod +x argocd-vault-plugin
sudo mv argocd-vault-plugin /usr/local/bin
#On macOS via Homebrew
brew install argocd-vault-plugin

sh -c "find . -name '*.yaml' -exec grep -l \"<path\\|avp\\.kubernetes\\.io/path\" {} \;"
sh -c "find . -name '*.yaml' | xargs -I {} grep \"<path\\|avp\\.kubernetes\\.io/path\" {} | grep ."
- "find . -name 'secret.yaml'"
