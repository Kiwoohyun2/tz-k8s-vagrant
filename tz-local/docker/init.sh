#!/usr/bin/env bash

# bash /init.sh
cd /vagrant/tz-local/docker

echo "VAULT_TOKEN: ${VAULT_TOKEN}"

rm -Rf /vagrant/info

export AWS_PROFILE=default
function propProject {
	grep "${1}" "/vagrant/resources/project" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
export k8s_project=$(propProject 'project')
export aws_account_id=$(propProject 'aws_account_id')
PROJECT_BASE='/vagrant/terraform-aws-k8s/workspace/base'

function propConfig {
  grep "${1}" "/vagrant/resources/config" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}

echo "k8s_project: ${k8s_project}"

echo "
export VAULT_ADDR=http://vault.${k8s_domain}
alias k='kubectl'
alias KUBECONFIG='~/.kube/config'
alias base='cd /vagrant/terraform-aws-k8s/workspace/base'
alias scripts='cd /vagrant/scripts'
alias tplan='terraform plan -var-file=".auto.tfvars"'
alias tapply='terraform apply -var-file=".auto.tfvars" -auto-approve'
alias ll='ls -al'
export PATH=\"/root/.krew/bin:$PATH\"
" > /root/.bashrc

cat >> /root/.bashrc <<EOF
function prop {
  key="\${2}=" file="/root/.k8s/\${1}" rslt=\$(grep "\${3:-}" "\$file" -A 10 | grep "\$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g')
  [[ -z "\$rslt" ]] && key="\${2} = " && rslt=\$(grep "\${3:-}" "\$file" -A 10 | grep "\$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g')
  rslt=\$(echo "\$rslt" | tr -d '\n' | tr -d '\r')
  echo "\$rslt"
}
EOF

chown -Rf topzone:topzone /home/topzone/.bashrc
cp -Rf /root/.bashrc /home/topzone/.bashrc

echo "###############"
if [[ "${INSTALL_INIT}" == 'true' || ! -f "/root/.k8s/config" ]]; then
  VERSION=$(curl -L -f --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' || echo "v2.8.4")
sudo curl -L -f -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64 || sudo wget --no-check-certificate -O /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
  sudo chmod +x /usr/local/bin/argocd

  (
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -L -f -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
  )
fi

kubectl krew install neat

#wget https://github.com/lensapp/lens/releases/download/v4.1.5/Lens-4.1.5.amd64.deb
#sudo dpkg -i Lens-4.1.5.amd64.deb

export KUBECONFIG=`ls kubeconfig_${k8s_project}*`
cp -Rf $KUBECONFIG /vagrant/config_${k8s_project}
sudo mkdir -p /root/.kube
sudo cp -Rf $KUBECONFIG /root/.kube/config
sudo chmod -Rf 600 /root/.kube/config
mkdir -p /home/topzone/.kube
cp -Rf $KUBECONFIG /home/topzone/.kube/config
sudo chmod -Rf 600 /home/topzone/.kube/config
export KUBECONFIG=/home/topzone/.kube/config
sudo chown -Rf topzone:topzone /home/topzone

echo "      env:" >> ${PROJECT_BASE}/kubeconfig_${k8s_project}
echo "        - name: AWS_PROFILE" >> ${PROJECT_BASE}/kubeconfig_${k8s_project}
echo '          value: '"${k8s_project}"'' >> ${PROJECT_BASE}/kubeconfig_${k8s_project}

#master_ip=`terraform output | grep -A 2 "public_ip" | head -n 1 | awk '{print $3}'`
#export master_ip=`echo $master_ip | sed -e 's/\"//g;s/ //;s/,//'`

# bash /vagrant/scripts/k8s_addtion.sh

#bastion_ip=$(terraform output | grep "bastion" | awk '{print $3}')
#echo "
#Host ${bastion_ip}
#  StrictHostKeyChecking   no
#  LogLevel                ERROR
#  UserKnownHostsFile      /dev/null
#  IdentitiesOnly yes
#  IdentityFile /root/.ssh/${k8s_project}
#" >> /root/.ssh/config
#sudo chown -Rf topzone:topzone /root/.ssh/config

#secondary_az1_ip=$(terraform output | grep "secondary-az1" | awk '{print $3}')

echo "
##[ Summary ]##########################################################
  - in VM
    export KUBECONFIG='/vagrant/config_${k8s_project}'

  - outside of VM
    export KUBECONFIG='config_${k8s_project}'

  - kubectl get nodes

  - ${k8s_project} bastion:
    ssh ubuntu@${bastion_ip}
    chmod 600 /home/topzone/resources/${k8s_project}
#  - secondary-az1: ssh -i /home/topzone/resources/${k8s_project} ubuntu@${secondary_az1_ip}

#######################################################################
" >> /vagrant/info
cat /vagrant/info

sudo /usr/sbin/sshd -D

exit 0

#helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
#helm repo update
#helm install prometheus-operator prometheus-community/kube-prometheus-stack
