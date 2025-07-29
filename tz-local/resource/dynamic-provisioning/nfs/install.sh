#!/usr/bin/env bash

source /root/.bashrc
cd /vagrant/tz-local/resource/dynamic-provisioning/nfs

shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

# install NFS in k8s
#https://github.com/kubernetes-csi/csi-driver-nfs/blob/master/deploy/example/nfs-provisioner/README.md

helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
#helm show values nfs-subdir-external-provisioner/nfs-subdir-external-provisioner > values.yaml
helm repo update
#--reuse-values
helm uninstall nfs-subdir-external-provisioner -n nfs-provisioner
helm upgrade --debug --install --reuse-values nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --create-namespace \
  --namespace nfs-provisioner \
  --set nfs.server=192.168.0.100 \
  --set nfs.path=/srv/nfs

## 1. Install NFS CSI driver master version on a kubernetes cluster
curl -skSL https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/v4.9.0/deploy/install-driver.sh | bash -s v4.9.0 --
sleep 60

k -n kube-system get pod -o wide -l app=csi-nfs-controller
k -n kube-system get pod -o wide -l app=csi-nfs-node

## 3. Verifying a driver installation
k get csinodes \
-o jsonpath='{range .items[*]} {.metadata.name}{": "} {range .spec.drivers[*]} {.name}{"\n"} {end}{end}'

#k apply -f nginx-pod.yaml
#k exec nginx-nfs2-example -n default -- bash -c "findmnt /var/www -o TARGET,SOURCE,FSTYPE"
#k delete -f nginx-pod.yaml

cd /vagrant/tz-local/resource/dynamic-provisioning/nfs
###############################################################
# !!! Storage Class Usage (Dynamic Provisioning)
###############################################################
k delete -f dynamic-provisioning-nfs.yaml
k apply -f dynamic-provisioning-nfs.yaml
k apply -f dynamic-provisioning-nfs-test.yaml
k get pv,pvc
sleep 30
k delete -f dynamic-provisioning-nfs-test.yaml

###############################################################
# !!! PV/PVC Usage (Static Provisioning)
###############################################################
#k delete -f static-provisioning-nfs.yaml
#k apply -f static-provisioning-nfs.yaml
#k apply -f static-provisioning-nfs-test.yaml
#k get pv,pvc
#k delete -f static-provisioning-nfs-test.yaml

exit 0