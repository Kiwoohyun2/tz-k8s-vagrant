#!/usr/bin/env bash

#set -x

export ANSIBLE_CONFIG=/root/ansible.cfg

if [ -d /vagrant ]; then
  cd /vagrant
fi

sudo rm -Rf kubespray
git clone https://github.com/kubernetes-sigs/kubespray.git --branch release-2.26
rm -Rf kubespray/inventory/test-cluster

cp -rfp kubespray/inventory/sample kubespray/inventory/test-cluster
cp -Rf resource/kubespray/addons.yml kubespray/inventory/test-cluster/group_vars/k8s_cluster/addons.yml
cp -Rf resource/kubespray/k8s-cluster.yml kubespray/inventory/test-cluster/group_vars/k8s_cluster/k8s-cluster.yml

cp -Rf resource/kubespray/inventory.ini kubespray/inventory/test-cluster/inventory.ini
cp -Rf scripts/local/config.cfg /root/.ssh/config

cd kubespray
sudo pip3 install -r requirements.txt
cd ..

#/etc/ansible/ansible.cfg
cat <<EOF > /root/ansible.cfg
[defaults]
roles_path = /vagrant/kubespray/roles
EOF

ansible all -i resource/kubespray/inventory.ini -m ping -u root
ansible all -i resource/kubespray/inventory.ini --list-hosts -u root

# to reset on each node.
#kubeadm reset
#ansible-playbook -u root -i resource/kubespray/inventory.ini kubespray/reset.yml \
#  --become --become-user=root --extra-vars "reset_confirmation=yes"

iptables --policy INPUT   ACCEPT
iptables --policy OUTPUT  ACCEPT
iptables --policy FORWARD ACCEPT
iptables -Z # zero counters
iptables -F # flush (delete) rules
iptables -X # delete all extra chains
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
rm -Rf $HOME/.kube

# install k8s
ansible-playbook -u root -i resource/kubespray/inventory.ini \
  --private-key .ssh/tz_rsa --become --become-user=root \
  kubespray/cluster.yml
#ansible-playbook -i resource/kubespray/inventory.ini --become --become-user=root cluster.yml

sudo cp -Rf /root/.kube /home/topzone/
sudo chown -Rf topzone:topzone /home/topzone/.kube
sudo cp -Rf /root/.kube/config /vagrant/.ssh/kubeconfig_tz-k8s-vagrant

sed -ie "s|127.0.0.1|192.168.0.100|g" /vagrant/.ssh/kubeconfig_tz-k8s-vagrant

echo "## [ install kubectl ] ######################################################"
sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2 curl

# Download kubectl with error checking
echo "Downloading kubectl..."
if curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; then
    echo "kubectl downloaded successfully"
    if [ -f kubectl ]; then
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        echo "kubectl installed successfully"
        rm -f kubectl
    else
        echo "Error: kubectl file not found after download"
        exit 1
    fi
else
    echo "Error: Failed to download kubectl"
    exit 1
fi

echo "## [ install helm3 ] ######################################################"
sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
sudo bash get_helm.sh
sudo rm -Rf get_helm.sh

echo "## [ install additional tools ] ######################################################"
# Install unzip
sudo apt-get install -y unzip

# Install wget if not available
if ! command -v wget &> /dev/null; then
    sudo apt-get install -y wget
fi

echo "## [ install consul ] ######################################################"
# Install consul if not available
if ! command -v consul &> /dev/null; then
    echo "Downloading consul..."
    if wget https://releases.hashicorp.com/consul/1.8.4/consul_1.8.4_linux_amd64.zip; then
        echo "Consul downloaded successfully"
        if [ -f consul_1.8.4_linux_amd64.zip ]; then
            unzip consul_1.8.4_linux_amd64.zip
            sudo mv consul /usr/local/bin/
            rm -f consul_1.8.4_linux_amd64.zip
            echo "Consul installed successfully."
        else
            echo "Error: consul zip file not found after download"
            exit 1
        fi
    else
        echo "Error: Failed to download consul"
        exit 1
    fi
else
    echo "Consul is already installed."
fi

echo "## [ install vault ] ######################################################"
# Install vault if not available
if ! command -v vault &> /dev/null; then
    VAULT_VERSION="1.3.1"
    echo "Downloading vault..."
    if wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip; then
        echo "Vault downloaded successfully"
        if [ -f vault_${VAULT_VERSION}_linux_amd64.zip ]; then
            unzip vault_${VAULT_VERSION}_linux_amd64.zip
            sudo mv vault /usr/local/bin/
            rm -f vault_${VAULT_VERSION}_linux_amd64.zip
            echo "Vault installed successfully."
        else
            echo "Error: vault zip file not found after download"
            exit 1
        fi
    else
        echo "Error: Failed to download vault"
        exit 1
    fi
else
    echo "Vault is already installed."
fi

exit 0

