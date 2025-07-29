#!/usr/bin/env bash

#https://github.com/hashicorp/vault-helm/issues/243
#https://www.vaultproject.io/docs/platform/k8s/helm/devops-devs/standalone-tls

source /root/.bashrc
#bash /vagrant/tz-local/resource/vault/vault-injection/cert.sh mobile
cd /vagrant/tz-local/resource/vault/vault-injection

if [[ "$1" == "" ]]; then
  NAMESPACE=vault
else
  NAMESPACE=$1
fi

SERVICE=vault
SECRET_NAME=vault-tls
CSR_NAME=vault-csr
BASENAME=vault
TMPDIR=./cert

mkdir $TMPDIR
# Create private key
openssl genrsa -out ${TMPDIR}/vault.key 2048

# Create a file ${TMPDIR}/${NAMESPACE}-csr.conf with the following contents
cat <<EOF >${TMPDIR}/${BASENAME}-csr.conf
[ req ]
default_bits = 2048
prompt = no
encrypt_key = yes
default_md = sha256
distinguished_name = dn
req_extensions = v3_req
[ dn ]
C = NO
ST = Oslo
L = Oslo
O = Personal
emailAddress = devops@okestro.me
CN = ${SERVICE}.${NAMESPACE}.svc
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${SERVICE}
DNS.2 = ${SERVICE}.${NAMESPACE}
DNS.3 = ${SERVICE}.${NAMESPACE}.svc
DNS.4 = ${SERVICE}.${NAMESPACE}.svc.cluster.local
IP.1  = 127.0.0.1
EOF

# Create a CSR
openssl req -config ${TMPDIR}/${BASENAME}-csr.conf -new -key ${TMPDIR}/${BASENAME}.key -subj "/CN=${SERVICE}.${NAMESPACE}.svc" -out ${TMPDIR}/${BASENAME}.csr

# Create a file ${TMPDIR}/${BASENAME}.yaml with the following contents
cat <<EOF >${TMPDIR}/${BASENAME}-csr.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${CSR_NAME}
spec:
  groups:
  - system:authenticated
  request: $(cat ${TMPDIR}/${BASENAME}.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

# Delete CSR and secret if exist
kubectl delete secret ${SERVICE_NAME} --namespace ${NAMESPACE}
kubectl delete csr ${CSR_NAME} --namespace ${NAMESPACE}

# Send the CSR to Kubernetes.
kubectl create -f ${TMPDIR}/${BASENAME}-csr.yaml --namespace ${NAMESPACE}

#If this process is automated, you may need to wait to ensure the CSR has been received and stored
kubectl get csr ${CSR_NAME} --namespace ${NAMESPACE}
## NAME        AGE     REQUESTOR      CONDITION
## vault-csr   2m44s   masterclient   Pending

# Approve the CSR in Kubernetes
kubectl certificate approve ${CSR_NAME} --namespace ${NAMESPACE}
## certificatesigningrequest.certificates.k8s.io/vault-csr approved

# Retrieve the certificate.
## If this process is automated, you may need to wait to ensure the certificate has been created. If it hasn't, this will return an empty string.
serverCert=$(kubectl get csr ${CSR_NAME} -o jsonpath='{.status.certificate}')
kubectl describe csr ${CSR_NAME}

# Write the certificate out to the CRT file
echo "${serverCert}" | openssl base64 -d -A -out ${TMPDIR}/${BASENAME}.crt

# Retrieve Kubernetes CA
kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 -d > ${TMPDIR}/${BASENAME}.ca

# Delete secret (if needed)
kubectl delete secret ${SECRET_NAME} -n ${NAMESPACE}

# Store the key, cert, and Kubernetes CA into Kubernetes secrets.
### This will create files /vault/userconfig/vault.ca , /vault/userconfig/vault.crt, /vault/userconfig/vault.key in the vault Pods
### values.yaml: Update server.ha.config:listener, injection.cert:certName,certKey
kubectl create secret generic ${SECRET_NAME} \
    --namespace ${NAMESPACE} \
    --from-file=${BASENAME}.key=${TMPDIR}/${BASENAME}.key \
    --from-file=${BASENAME}.crt=${TMPDIR}/${BASENAME}.crt \
    --from-file=${BASENAME}.ca=${TMPDIR}/${BASENAME}.ca

# Verify the certificate:
openssl x509 -in ${TMPDIR}/${BASENAME}.crt -noout -text
