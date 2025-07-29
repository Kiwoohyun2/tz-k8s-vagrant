#!/usr/bin/env bash

source /root/.bashrc
function prop { key="${2}=" file="/root/.k8s/${1}" rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); [[ -z "$rslt" ]] && key="${2} = " && rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); rslt=$(echo "$rslt" | tr -d '\n' | tr -d '\r'); echo "$rslt"; }
#bash /vagrant/tz-local/resource/vault/vault-injection/install.sh
cd /vagrant/tz-local/resource/vault/vault-injection

k8s_project=$(prop 'project' 'project')
k8s_domain=$(prop 'project' 'domain')
VAULT_TOKEN=$(prop 'project' 'vault')

export VAULT_ADDR="http://vault.default.${k8s_project}.${k8s_domain}"
vault login ${VAULT_TOKEN}

curl -s ${VAULT_ADDR}/v1/sys/seal-status | jq
EXTERNAL_VAULT_ADDR="http://vault.default.${k8s_project}.${k8s_domain}"
echo $EXTERNAL_VAULT_ADDR

bash /vagrant/tz-local/resource/vault/vault-injection/cert.sh
kubectl get csr -o name | xargs kubectl certificate approve

vault secrets enable -path=secret/ kv
vault auth enable kubernetes

#kubectl -n vault create serviceaccount vault-auth
cp -Rf vault-auth-service-account.yaml vault-auth-service-account.yaml_bak
sed -i "s/namespace: vault/namespace: vault/g" vault-auth-service-account.yaml_bak
kubectl -n vault delete -f vault-auth-service-account.yaml_bak
kubectl -n vault apply -f vault-auth-service-account.yaml_bak
kubectl -n vault apply -f vault-auth-service-account2.yaml
# Prepare kube api server data
cat <<EOF | kubectl -n vault apply -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth
  annotations:
    kubernetes.io/service-account.name: "vault-auth"
type: kubernetes.io/service-account-token
EOF
export SECRET_NAME="vault-auth"
export SA_JWT_TOKEN=$(kubectl -n vault get secret $SECRET_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
export K8S_HOST="$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')"
export SA_CA_CRT="$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)"

echo "SECRET_NAME: ${SECRET_NAME}"
echo "SA_JWT_TOKEN: ${SA_JWT_TOKEN}"
echo "K8S_HOST: ${K8S_HOST}"
echo "SA_CA_CRT: ${SA_CA_CRT}"

vault secrets enable -path=secret/ kv
vault auth enable kubernetes
vault write auth/kubernetes/config \
        token_reviewer_jwt="${SA_JWT_TOKEN}" \
        kubernetes_host="${K8S_HOST}" \
        kubernetes_ca_cert="${SA_CA_CRT}" \
        issuer="https://kubernetes.default.svc.cluster.local"
#        disable_iss_validation=true

export VAULT_ADDR="http://vault.default.${k8s_project}.${k8s_domain}"
#export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200
vault write auth/userpass/users/Kiwoohyun2 password=1111111 policies=tz-vault-devops
vault login -method=userpass username=Kiwoohyun2 password=1111111

## ********* in vault pod *********
#VAULT_ADDR=http://vault.vault.svc.cluster.local:8200
#vault login s.H7TwKTLuJmBx0UgAg5aAeGMN
#vault write auth/kubernetes/config
#    kubernetes_host="${K8S_API_SERVER}"
#    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
#    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

vault login ${VAULT_TOKEN}

vault read auth/kubernetes/config

vault write auth/kubernetes/role/devops-prod \
        bound_service_account_names=devops-prod-svcaccount \
        bound_service_account_namespaces=devops \
        policies=tz-vault-devops-prod \
        ttl=24h

vault list auth/kubernetes/role
vault read auth/kubernetes/role/devops-prod

exit 0

