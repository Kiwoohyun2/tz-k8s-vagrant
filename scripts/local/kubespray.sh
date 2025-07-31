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

# Comprehensive fix for Windows Git Bash compatibility issues
echo "Applying comprehensive fixes for Windows Git Bash compatibility..."

# Fix all symlink issues in kubespray
cd kubespray
echo "Fixing all symlink issues..."

# Remove all existing symlinks and recreate them properly
find . -type l -delete
find . -name "*.py" -path "*/library/*" -exec rm -f {} \;

# Recreate all necessary symlinks
if [ -d "plugins/modules" ] && [ -d "library" ]; then
    cd library
    for file in ../plugins/modules/*.py; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            ln -sf "../plugins/modules/$filename" "$filename"
            echo "Created symlink: $filename"
        fi
    done
    cd ..
fi

# Fix Ansible configuration for better module discovery
echo "Configuring Ansible for better module discovery..."
mkdir -p ~/.ansible/collections/ansible_collections/kubernetes/core/plugins/modules
ln -sf /vagrant/kubespray/plugins/modules/* ~/.ansible/collections/ansible_collections/kubernetes/core/plugins/modules/

# Verify kube.py symlink
echo "Verifying kube.py symlink..."
if [ -L "library/kube.py" ]; then
    echo "kube.py symlink is correct"
    ls -la library/kube.py
else
    echo "ERROR: kube.py symlink is broken, recreating..."
    cd library
    rm -f kube.py
    ln -sf ../plugins/modules/kube.py kube.py
    ls -la kube.py
    cd ..
fi

cd ..

cd kubespray
# Fix Ansible version compatibility issue
echo "Installing specific Ansible version for Kubespray compatibility..."
sudo pip3 uninstall -y ansible
sudo pip3 cache purge
sudo pip3 install --no-cache-dir --timeout=300 "ansible==2.10.7"
sudo pip3 install -r requirements.txt
cd ..

#/etc/ansible/ansible.cfg
cat <<EOF > /root/ansible.cfg
[defaults]
roles_path = /vagrant/kubespray/roles
library = /vagrant/kubespray/library
module_utils = /vagrant/kubespray/module_utils
host_key_checking = False
timeout = 300
retry_files_enabled = False
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

# install k8s with comprehensive error handling
echo "Starting Kubernetes cluster installation..."
ansible-playbook -u root -i resource/kubespray/inventory.ini \
  --private-key .ssh/tz_rsa --become --become-user=root \
  --timeout=300 \
  kubespray/cluster.yml
#ansible-playbook -i resource/kubespray/inventory.ini --become --become-user=root cluster.yml

# Copy kubeconfig with error handling
if [ -d "/root/.kube" ]; then
    sudo cp -Rf /root/.kube /home/topzone/
    sudo chown -Rf topzone:topzone /home/topzone/.kube
    if [ -f "/root/.kube/config" ]; then
        sudo cp -Rf /root/.kube/config /vagrant/.ssh/kubeconfig_tz-k8s-vagrant
    else
        echo "WARNING: /root/.kube/config not found"
    fi
else
    echo "WARNING: /root/.kube directory not found"
fi

sed -ie "s|127.0.0.1|192.168.0.100|g" /vagrant/.ssh/kubeconfig_tz-k8s-vagrant

echo "## [ install kubectl ] ######################################################"
sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2 curl

# Download kubectl with error checking and proper redirect handling
echo "Downloading kubectl..."

# Get the latest version with proper redirect handling
KUBECTL_VERSION=$(curl -L -s -f https://dl.k8s.io/release/stable.txt 2>/dev/null || echo "v1.28.0")
echo "Using kubectl version: ${KUBECTL_VERSION}"

# Download kubectl with proper redirect handling
KUBECTL_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
echo "Downloading from: ${KUBECTL_URL}"

# Try multiple download methods for better compatibility
if curl -L -f "${KUBECTL_URL}" -o kubectl; then
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
    echo "Error: Failed to download kubectl with curl, trying wget..."
    if wget --no-check-certificate "${KUBECTL_URL}" -O kubectl; then
        echo "kubectl downloaded successfully with wget"
        if [ -f kubectl ]; then
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            echo "kubectl installed successfully"
            rm -f kubectl
        else
            echo "Error: kubectl file not found after wget download"
            exit 1
        fi
    else
        echo "Error: Failed to download kubectl with both curl and wget"
        exit 1
    fi
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
    if wget --no-check-certificate https://releases.hashicorp.com/consul/1.8.4/consul_1.8.4_linux_amd64.zip; then
        echo "Consul downloaded successfully"
        if [ -f consul_1.8.4_linux_amd64.zip ]; then
            unzip consul_1.8.4_linux_amd64.zip
            sudo mv consul /usr/local/bin/
            sudo chmod +x /usr/local/bin/consul
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
    if wget --no-check-certificate https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip; then
        echo "Vault downloaded successfully"
        if [ -f vault_${VAULT_VERSION}_linux_amd64.zip ]; then
            unzip vault_${VAULT_VERSION}_linux_amd64.zip
            sudo mv vault /usr/local/bin/
            sudo chmod +x /usr/local/bin/vault
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

