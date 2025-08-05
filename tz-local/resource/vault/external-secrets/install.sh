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

# External Secrets 설치 후 Webhook 비활성화
echo "External Secrets 설치 완료. Webhook 비활성화 중..."
sleep 10
kubectl patch validatingwebhookconfiguration external-secrets-webhook --type='json' -p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Ignore"}]' 2>/dev/null || echo "Webhook 비활성화 실패 (무시됨)"

#export VAULT_ADDR=http://vault.default.${k8s_project}.${k8s_domain}
#vault login ${VAULT_TOKEN}
#vault kv get secret/devops-prod/dbinfo

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
        kubernetes:
          mountPath: "kubernetes"
          role: "PROJECT"
          serviceAccountRef:
            name: "PROJECT-svcaccount"
' > secret.yaml

    cp secret.yaml secret.yaml_bak
    sed -i "s|PROJECT|${project}|g" secret.yaml_bak
    sed -i "s|NAMESPACE|${namespace}|g" secret.yaml_bak
    kubectl apply -f secret.yaml_bak
    kubectl patch serviceaccount ${project}-svcaccount -p '{"imagePullSecrets": [{"name": "tz-registrykey"}]}' -n ${namespace}

    if [ "${STAGING}" == "prod" ]; then
      cp secret.yaml secret.yaml_bak
      sed -i "s|PROJECT|${project_stg}|g" secret.yaml_bak
      sed -i "s|NAMESPACE|${namespace}|g" secret.yaml_bak
      kubectl apply -f secret.yaml_bak
      kubectl patch serviceaccount ${project_stg}-svcaccount -p '{"imagePullSecrets": [{"name": "tz-registrykey"}]}' -n ${namespace}
    fi
  fi
done

rm -Rf secret.yaml secret.yaml_bak

exit 0
kubectl apply -f test.yaml
kubectl -n devops describe externalsecret devops-externalsecret
kubectl get SecretStores,ClusterSecretStores,ExternalSecrets --all-namespaces

