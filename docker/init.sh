#!/usr/bin/env bash

# bash /init.sh
cd /vagrant/tz-local/docker
export KUBE_CONFIG_PATH=/root/.kube/config

echo "VAULT_TOKEN: ${VAULT_TOKEN}"

rm -Rf /vagrant/info

function propProject {
	grep "${1}" "/vagrant/resources/project" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}
export k8s_project=$(propProject 'project')

function propConfig {
  grep "${1}" "/vagrant/resources/config" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'
}

echo "k8s_project: ${k8s_project}"

echo "
export VAULT_ADDR=http://vault.${k8s_domain}
export KUBE_CONFIG_PATH='~/.kube/config'
alias k='kubectl'
alias KUBECONFIG='~/.kube/config'
alias base='cd /vagrant/terraform-aws-eks/workspace/base'
alias base2='cd /vagrant/terraform-aws-iam/workspace/base'
alias scripts='cd /vagrant/scripts'
alias tplan='terraform plan -var-file=".auto.tfvars"'
alias tapply='terraform apply -var-file=".auto.tfvars" -auto-approve'
alias ll='ls -al'
export PAGER=cat
export PATH=\"/root/.krew/bin:$PATH\"
" >> /root/.bashrc

cat >> /root/.bashrc <<EOF
function prop {
  key="\${2}=" file="/root/.k8s/\${1}" rslt=\$(grep "\${3:-}" "\$file" -A 10 | grep "\$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g')
  [[ -z "\$rslt" ]] && key="\${2} = " && rslt=\$(grep "\${3:-}" "\$file" -A 10 | grep "\$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g')
  rslt=\$(echo "\$rslt" | tr -d '\n' | tr -d '\r')
  echo "\$rslt"
}
EOF

cp -Rf /root/.bashrc /home/topzone/.bashrc
chown -Rf topzone:topzone /home/topzone/.bashrc

echo "###############"
if [[ "${INSTALL_INIT}" == 'true' || ! -f "/root/.k8s/config" ]]; then
  VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
  sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
  sudo chmod +x /usr/local/bin/argocd

  (
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
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

echo "
##[ Summary ]##########################################################
  - in VM
    export KUBECONFIG='/vagrant/kubeconfig_${k8s_project}'

  - outside of VM
    export KUBECONFIG='kubeconfig_${k8s_project}'

  - kubectl get nodes
#######################################################################
" >> /vagrant/info
cat /vagrant/info

sudo /usr/sbin/sshd -D

exit 0

#helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
#helm repo update
#helm install prometheus-operator prometheus-community/kube-prometheus-stack

###################################################################
cd /vagrant/tz-local/docker

dockerhub_id=$(prop 'project' 'dockerhub_id')
dockerhub_password=$(prop 'project' 'dockerhub_password')
docker_url=$(prop 'project' 'docker_url')

SNAPSHOT_IMG=devops-utils2
TAG=latest

DOCKER_URL=index.docker.io
dockerhub_id=Kiwoohyun2
dockerhub_password=''
echo $dockerhub_password | docker login -u ${dockerhub_id} --password-stdin ${DOCKER_URL}

#docker container stop $(docker container ls -a -q) && docker system prune -a -f --volumes
TAG=latest
# --no-cache
docker image build -t ${SNAPSHOT_IMG} . -f BaseDockerfile
docker tag ${SNAPSHOT_IMG}:latest ${dockerhub_id}/${SNAPSHOT_IMG}:${TAG}
docker push ${dockerhub_id}/${SNAPSHOT_IMG}:${TAG}

#docker tag ${DOCKER_URL}/${SNAPSHOT_IMG}:${TAG} ${DOCKER_URL}/devops-utils2:latest
#docker push ${DOCKER_URL}/devops-utils2:latest

docker tag ${SNAPSHOT_IMG}:latest Kiwoohyun2/${SNAPSHOT_IMG}:${TAG}
docker push Kiwoohyun2/${SNAPSHOT_IMG}:${TAG}
