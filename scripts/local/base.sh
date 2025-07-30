#!/usr/bin/env bash

#set -x

##################################################################
# k8s base
##################################################################
export DEBIAN_FRONTEND=noninteractive

if [ -d /vagrant ]; then
  cd /vagrant
fi

sudo groupadd topzone
sudo useradd -g topzone -d /home/topzone -s /bin/bash -m topzone
cat <<EOF > pass.txt
topzone:topzone
EOF
sudo chpasswd < pass.txt
sudo mkdir -p /home/topzone/.ssh &&
  sudo chown -Rf topzone:topzone /home/topzone

MYKEY=tz_rsa
cp -Rf /vagrant/.ssh/${MYKEY} /root/.ssh/${MYKEY}
cp -Rf /vagrant/.ssh/${MYKEY}.pub /root/.ssh/${MYKEY}.pub
touch /home/topzone/.ssh/authorized_keys
cp /home/topzone/.ssh/authorized_keys /root/.ssh/authorized_keys
cat /root/.ssh/${MYKEY}.pub >> /root/.ssh/authorized_keys
chown -R root:root /root/.ssh \
  chmod -Rf 400 /root/.ssh
rm -Rf /home/topzone/.ssh \
  && cp -Rf /root/.ssh /home/topzone/.ssh \
  && chown -Rf topzone:topzone /home/topzone/.ssh \
  && chmod -Rf 700 /home/topzone/.ssh \
  && chmod -Rf 600 /home/topzone/.ssh/*

cat <<EOF >> /etc/resolv.conf
nameserver 1.1.1.1 #cloudflare DNS
nameserver 8.8.8.8 #Google DNS
EOF

sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
#sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo apt-get update
sudo apt-get install -y python3 python3-pip net-tools git runc

#sudo apt install --reinstall ca-certificates -y

sudo tee /etc/modules-load.d/containerd.conf << EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/kubernetes.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

#sudo ufw enable
#sudo ufw allow 22
#sudo ufw allow 6443
sudo ufw disable

apt update
apt-get install -y nfs-server nfs-common
mkdir /srv/nfs
sudo chown nobody:nogroup /srv/nfs
sudo chmod 0777 /srv/nfs
cat << EOF >> /etc/exports
/srv/nfs 192.168.0.0/24(rw,no_subtree_check,no_root_squash)
EOF
systemctl enable --now nfs-server
exportfs -ar

apt-get install ntp -y
systemctl start ntp
systemctl enable ntp
#ntpdate pool.ntp.org

echo "##############################################"
echo "Ready to be added to k8s"
echo "##############################################"
cat  /vagrant/info

# manual test
#sudo mount -t nfs 192.168.0.200:/srv/nfs /mnt
## done

check_host=`cat /etc/hosts | grep 'kube-master'`
if [[ "${check_host}" == "" ]]; then
cat <<EOF >> /etc/hosts
192.168.0.100   kube-master
192.168.0.101   kube-node-1
192.168.0.102   kube-node-2

192.168.0.110   kube-slave-1
192.168.0.112   kube-slave-2
192.168.0.113   kube-slave-3

192.168.0.210   kube-slave-4
192.168.0.212   kube-slave-5
192.168.0.213   kube-slave-6

192.168.0.200   test.default.okestro-k8s.okestro.me consul.default.okestro-k8s.okestro.me vault.default.okestro-k8s.okestro.me
192.168.0.200   consul-server.default.okestro-k8s.okestro.me argocd.default.okestro-k8s.okestro.me
192.168.0.200   jenkins.default.okestro-k8s.okestro.me harbor.harbor.okestro-k8s.okestro.me
192.168.0.200   grafana.default.okestro-k8s.okestro.me prometheus.default.okestro-k8s.okestro.me alertmanager.default.okestro-k8s.okestro.me
192.168.0.200   grafana.default.okestro-k8s.okestro.me prometheus.default.okestro-k8s.okestro.me alertmanager.default.okestro-k8s.okestro.me
192.168.0.200   vagrant-demo-app.devops-dev.okestro-k8s.okestro.me

EOF
fi

