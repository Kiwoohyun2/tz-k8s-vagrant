#!/usr/bin/env bash

source /root/.bashrc
function prop { key="${2}=" file="/root/.k8s/${1}" rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); [[ -z "$rslt" ]] && key="${2} = " && rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); rslt=$(echo "$rslt" | tr -d '\n' | tr -d '\r'); echo "$rslt"; }
#bash /vagrant/tz-local/resource/vault/helm/install.sh
cd /vagrant/tz-local/resource/vault/helm

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

k8s_project=$(prop 'project' 'project')
k8s_domain=$(prop 'project' 'domain')
VAULT_TOKEN=$(prop 'project' 'vault')
NS=vault

helm repo add hashicorp https://helm.releases.hashicorp.com
helm search repo hashicorp/vault

helm uninstall vault -n vault
#k delete namespace vault
k create namespace vault

bash /vagrant/tz-local/resource/vault/vault-injection/cert.sh vault
bash /vagrant/tz-local/resource/vault/vault-injection/cert.sh vault

#helm show values hashicorp/vault > values2.yaml
cp -Rf values_cert.yaml values_cert.yaml_bak
sed -i "s/k8s_project/${k8s_project}/g" values_cert.yaml_bak
#--reuse-values
helm upgrade --debug --install vault hashicorp/vault -n vault -f values_cert.yaml_bak --version 0.25.0
kubectl taint nodes --all node-role.kubernetes.io/master-
#kubectl rollout restart statefulset.apps/vault -n vault

sleep 30
k get all -n vault

cp -Rf values_config.yaml values_config.yaml_bak
sed -i "s/k8s_project/${k8s_project}/g" values_config.yaml_bak
sed -i "s/k8s_domain/${k8s_domain}/g" values_config.yaml_bak
k apply -f values_config.yaml_bak -n vault

sleep 30
# to NodePort

#k patch svc vault-standby --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/0/nodePort","value":31700}]' -n vault
cp -Rf ingress-vault.yaml ingress-vault.yaml_bak
sed -ie "s/k8s_project/${k8s_project}/g" ingress-vault.yaml_bak
sed -ie "s/k8s_domain/${k8s_domain}/g" ingress-vault.yaml_bak
sed -ie "s|NS|${NS}|g" ingress-vault.yaml_bak
k delete -f ingress-vault.yaml_bak -n vault
k apply -f ingress-vault.yaml_bak -n vault

#k port-forward vault-0 8200:8200 -n vault &
k get pods -l app.kubernetes.io/name=vault -n vault

sleep 60
# vault operator init
# vault operator init -key-shares=3 -key-threshold=2
#export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_ADDR="http://vault.default.${k8s_project}.${k8s_domain}"
echo $VAULT_ADDR

k scale statefulset.apps/vault --replicas=0 -n vault
sleep 30
k scale statefulset.apps/vault --replicas=2 -n vault
sleep 30

echo "#######################################################"
echo "Initial Root Token vault!!!"
echo "#######################################################"
kubectl -n vault exec -ti vault-0 -- vault operator init -key-shares=3 -key-threshold=2 | sed 's/\x1b\[[0-9;]*m//g' > /vagrant/resources/unseal.txt
sleep 20
VAULT_TOKEN_NEW=$(cat /vagrant/resources/unseal.txt | grep "Initial Root Token:" | tail -n 1 | awk '{print $4}')
echo "#######################################################"
echo "VAULT_TOKEN_NEW: ${VAULT_TOKEN_NEW}"
echo "#######################################################"
if [[ "${VAULT_TOKEN_NEW}" != "" ]]; then
  awk '!/vault=/' /vagrant/resources/project > tmpfile && mv tmpfile /vagrant/resources/project
  echo "vault=${VAULT_TOKEN_NEW}" >> /vagrant/resources/project
  cp -Rf /vagrant/resources/project ~/.k8s/project
  mkdir -p /home/topzone/.k8s
  cp -Rf /vagrant/resources/project /home/topzone/.k8s/project
fi

VAULT_VERSION="1.3.1"
curl -L -f -sO https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip || wget --no-check-certificate https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip vault_${VAULT_VERSION}_linux_amd64.zip
rm -Rf vault_${VAULT_VERSION}_linux_amd64.zip
sudo mv vault /usr/local/bin/
sudo chmod +x /usr/local/bin/vault
vault --version

echo "run it in vault pods!: vault operator unseal"
exit 0

# Need to unseal vault manually !!!!
#echo k -n vault exec -ti vault-0 -- vault operator unseal
#k -n vault exec -ti vault-0 -- vault operator unseal # ... Unseal Key 1
#k -n vault exec -ti vault-0 -- vault operator unseal # ... Unseal Key 2,3,4,5
#
#echo k -n vault exec -ti vault-1 -- vault operator unseal
#k -n vault exec -ti vault-1 -- vault operator unseal # ... Unseal Key 1
#k -n vault exec -ti vault-1 -- vault operator unseal # ... Unseal Key 2,3,4,5
#
#echo k -n vault exec -ti vault-2 -- vault operator unseal
#k -n vault exec -ti vault-2 -- vault operator unseal # ... Unseal Key 1
#k -n vault exec -ti vault-2 -- vault operator unseal # ... Unseal Key 2,3,4,5

#vault -autocomplete-install
#complete -C /usr/local/bin/vault vault
#vault -h

kubectl label nodes kube-master master=yes
kubectl label nodes kube-node-1 master=yes
kubectl label nodes kube-node-2 master=yes

kubectl patch statefulset/vault -p '{"spec": {"template": {"spec": {"nodeSelector": {"master": "yes"}}}}}' -n vault

echo "
##[ Vault ]##########################################################
export VAULT_ADDR=http://vault.default.${k8s_project}.${k8s_domain}
vault login ${VAULT_TOKEN_NEW}

vault secrets list -detailed

vault kv list kv
vault kv put kv/my-secret my-value=yea
vault kv get kv/my-secret

vault kv put kv/tz-vault tz-value=yes
vault kv get kv/tz-vault

vault kv delete kv/tz-vault

vault kv metadata get kv/tz-vault
vault kv metadata delete kv/tz-vault

#vault secrets enable -path=kv kv

# macos
brew tap hashicorp/tap
brew install hashicorp/tap/vault
export VAULT_ADDR=http://vault.default.${k8s_project}.${k8s_domain}
vault login xxxx
vault secrets list -detailed

vault audit enable file file_path=/home/topzone/tmp/a.log

# path ex)
secrets
  apps
    app1_web
    app1_demon
  common
    api_key

# backup and restore
export CONSUL_HTTP_ADDR="consul.default.${k8s_project}.${k8s_domain}"
consul members

consul snapshot save /vagrant/tz-local/resource/vault/helm/backup.snap
consul snapshot restore /vagrant/tz-local/resource/vault/helm/backup.snap
#vault operator raft snapshot save /vagrant/tz-local/resource/vault/helm/backup.snap
#vault operator raft snapshot restore -force /vagrant/tz-local/resource/vault/helm/backup.snap

#######################################################################
" >> /vagrant/info
cat /vagrant/info

exit 0

