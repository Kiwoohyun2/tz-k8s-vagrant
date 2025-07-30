#!/usr/bin/env bash

#set -x

export ANSIBLE_CONFIG=/root/ansible.cfg
export DEBIAN_FRONTEND=noninteractive
echo "
export ANSIBLE_CONFIG=/root/ansible.cfg
alias k='kubectl'
alias ll='ls -al'
alias KUBECONFIG='~/.kube/config'
alias base='cd /vagrant'
export PATH=\"/root/.krew/bin:$PATH\"
" > /root/.bashrc

echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

if [ -d /vagrant ]; then
  cd /vagrant
fi

shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

bash /vagrant/scripts/local/base.sh

sudo apt-add-repository ppa:ansible/ansible -y
sudo apt update
sudo apt-get install python3-pip ansible net-tools jq -y
#sudo pip install --upgrade ansible
#sudo ansible-galaxy install --force container-engine/runc

sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y
curl -L -f -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - || echo "Docker GPG key download failed, but continuing..."
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
sudo apt-get update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io -y

cp -Rf scripts/local/config.cfg /root/.ssh/config

sudo rm -Rf /root/.k8s
sudo cp -Rf /vagrant/resources /root/.k8s

exit 0

sudo sed -i "s/\$KUBELET_EXTRA_ARGS/\$KUBELET_EXTRA_ARGS --node-ip=192.168.0.100/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
systemctl daemon-reload && systemctl restart kubelet
kubectl get nodes -o wide

## nfs server
## !!! Warning: Authentication failure. Retrying... after nfs setting and ubuntu up
sudo apt-get install nfs-common nfs-kernel-server rpcbind portmap -y
sudo mkdir -p /homedata
#sudo chmod -Rf 777 /home
#sudo chown -Rf nobody:nogroup /home
echo '/homedata 192.168.1.0/16(rw,sync,no_subtree_check)' >> /etc/exports
exportfs -a
systemctl stop nfs-kernel-server
systemctl start nfs-kernel-server
#service nfs-kernel-server status
showmount -e 192.168.0.100
#sudo mkdir /data
#mount -t nfs -vvvv 192.168.0.100:/homedata /data
#echo '192.168.0.100:/homedata /data  nfs      defaults    0       0' >> /etc/fstab
#sudo mount -t nfs -o resvport,rw 192.168.3.1:/Volumes/workspace/etc /Volumes/sambashare

k patch storageclass nfs-storageclass -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
k get storageclass,pv,pvc

