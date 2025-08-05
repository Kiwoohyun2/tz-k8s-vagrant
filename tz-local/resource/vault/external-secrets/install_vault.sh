#!/usr/bin/env bash

source /root/.bashrc
function prop { key="${2}=" file="/root/.k8s/${1}" rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); [[ -z "$rslt" ]] && key="${2} = " && rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); rslt=$(echo "$rslt" | tr -d '\n' | tr -d '\r'); echo "$rslt"; }

# WSL 환경 안전장치
echo "WSL 환경 확인 중..."
if [[ ! -d /vagrant ]]; then
  echo "오류: /vagrant 디렉토리를 찾을 수 없습니다!"
  echo "Vagrant VM이 제대로 시작되었는지 확인하세요."
  exit 1
fi

#bash /vagrant/tz-local/resource/vault/external-secrets/install.sh
cd /vagrant/tz-local/resource/vault/external-secrets

k8s_domain=$(prop 'project' 'domain')
k8s_project=$(prop 'project' 'project')
VAULT_TOKEN=$(prop 'project' 'vault')
NS=external-secrets

helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm uninstall external-secrets -n ${NS}
#--reuse-values
helm upgrade --debug --install external-secrets \
   external-secrets/external-secrets \
    -n ${NS} \
    --create-namespace \
    --set installCRDs=true

sleep 60

# External Secrets 설치 후 Webhook 비활성화
echo "External Secrets 설치 완료. Webhook 비활성화 중..."
kubectl patch validatingwebhookconfiguration external-secrets-webhook --type='json' -p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Ignore"}]' 2>/dev/null || echo "Webhook 비활성화 실패 (무시됨)"

export VAULT_ADDR=http://vault.default.${k8s_project}.${k8s_domain}
vault login ${VAULT_TOKEN}
#vault kv get secret/devops-prod/dbinfo
VAULT_TOKEN_EN=`echo -n ${VAULT_TOKEN} | openssl base64 -A`

#PROJECTS=(devops devops-dev)
PROJECTS=(devops devops-dev default argocd jenkins harbor)
for item in "${PROJECTS[@]}"; do
  if [[ "${item}" != "NAME" ]]; then
    STAGING="dev"
    if [[ "${item/*-dev/}" == "" ]]; then
      project=${item/-prod/}
      STAGING="dev"
      namespace=${project}
    else
      project=${item}-prod
      project_stg=${item}-stg
      STAGING="prod"
      namespace=${item}
    fi
    echo "=====================STAGING: ${STAGING}"
echo '
apiVersion: v1
kind: ServiceAccount
metadata:
  name: PROJECT-svcaccount
  namespace: "NAMESPACE"
---

apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: "PROJECT"
  namespace: "NAMESPACE"
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: "vault-token"
          key: "token"
---
apiVersion: v1
kind: Secret
metadata:
  name: vault-token
  namespace: "NAMESPACE"
data:
  token: VAULT_TOKEN_EN

' > secret.yaml

    cp secret.yaml secret.yaml_bak
    sed -i "s|PROJECT|${project}|g" secret.yaml_bak
    sed -i "s|NAMESPACE|${namespace}|g" secret.yaml_bak
    sed -i "s|VAULT_TOKEN_EN|${VAULT_TOKEN_EN}|g" secret.yaml_bak
    sed -i "s|k8s_project|${k8s_project}|g" secret.yaml_bak
    sed -i "s|k8s_domain|${k8s_domain}|g" secret.yaml_bak
#    kubectl delete -f secret.yaml_bak
    kubectl apply -f secret.yaml_bak
    kubectl patch serviceaccount ${project}-svcaccount -p '{"imagePullSecrets": [{"name": "tz-registrykey"}]}' -n ${namespace}

echo '
apiVersion: v1
kind: ServiceAccount
metadata:
  name: PROJECT-svcaccount
  namespace: NAMESPACE
' > account.yaml

    if [ "${STAGING}" == "prod" ]; then
      cp account.yaml account.yaml_bak
      sed -i "s|PROJECT|${item}|g" account.yaml_bak
      sed -i "s|NAMESPACE|${namespace}|g" account.yaml_bak
      #kubectl delete -f account.yaml_bak
      kubectl apply -f account.yaml_bak

      cp secret.yaml secret.yaml_bak
      sed -i "s|PROJECT|${project_stg}|g" secret.yaml_bak
      sed -i "s|NAMESPACE|${namespace}|g" secret.yaml_bak
      sed -i "s|VAULT_TOKEN_EN|${VAULT_TOKEN_EN}|g" secret.yaml_bak
      sed -i "s|k8s_project|${k8s_project}|g" secret.yaml_bak
      sed -i "s|k8s_domain|${k8s_domain}|g" secret.yaml_bak
#      kubectl delete -f secret.yaml_bak
      kubectl apply -f secret.yaml_bak
      kubectl patch serviceaccount ${project_stg}-svcaccount -p '{"imagePullSecrets": [{"name": "tz-registrykey"}]}' -n ${namespace}

      cp account.yaml account.yaml_bak
      sed -i "s|PROJECT|${project_stg}|g" account.yaml_bak
      sed -i "s|NAMESPACE|${namespace}|g" account.yaml_bak
      #kubectl delete -f account.yaml_bak
      kubectl apply -f account.yaml_bak
    else
      cp account.yaml account.yaml_bak
      sed -i "s|PROJECT|${project}|g" account.yaml_bak
      sed -i "s|NAMESPACE|${namespace}|g" account.yaml_bak
      #kubectl delete -f account.yaml_bak
      kubectl apply -f account.yaml_bak
      kubectl patch serviceaccount ${project}-svcaccount -p '{"imagePullSecrets": [{"name": "tz-registrykey"}]}' -n ${namespace}
    fi
  fi
done

exit 0

kubectl apply -f test.yaml

rm -Rf secret.yaml secret.yaml_bak account.yaml account.yaml_bak

kubectl apply -f test.yaml
kubectl -n devops describe externalsecret devops-externalsecret
kubectl get SecretStores,ClusterSecretStores,ExternalSecrets --all-namespaces

NAMESPACE=devops
STAGING=prod

PROJECTS=(kubeconfig_eks-main-p kubeconfig_okestro-k8s kubeconfig_eks-main-s kubeconfig_okestro-k8s kubeconfig_eks-main-c devops.pub devops.pem devops credentials config auth.env ssh_config)
for item in "${PROJECTS[@]}"; do
  if [[ "${item}" != "NAME" ]]; then
    bash vault.sh fput ${NAMESPACE}-${STAGING} ${item} ${item}
    #bash vault.sh fget ${NAMESPACE}-${STAGING} ${item} > ${item}
  fi
done
