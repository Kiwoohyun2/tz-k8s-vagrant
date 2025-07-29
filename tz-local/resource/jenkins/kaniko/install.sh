#!/usr/bin/env bash

cd /vagrant/tz-local/resource/jenkins/kaniko

k8s_project=$(prop 'project' 'project')
k8s_domain=$(prop 'project' 'domain')
VAULT_TOKEN=$(prop 'project' 'vault')

#set -x
vault -autocomplete-install
complete -C /usr/local/bin/vault vault
#vault -h

kubectl get secret harbor-release-ingress -n harbor -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
echo "Harbor12345" | docker login harbor.harbor.okestro-k8s.okestro.me -u admin --password-stdin
docker build -t harbor.harbor.okestro-k8s.okestro.me/okestro-k8s/kaniko-executor:v1.7.0-debug .
docker push harbor.harbor.okestro-k8s.okestro.me/okestro-k8s/kaniko-executor:v1.7.0-debug

/kaniko/executor --dockerfile=Dockerfile --context=/root/shared-data/tz-demo-app --build-arg NODE_ENV=development \
--destination=harbor.harbor.okestro-k8s.okestro.me/okestro-k8s/tz-demo-app:13 \
--use-new-run --cleanup --force --skip-tls-verify


/kaniko/executor --dockerfile=Dockerfile --context=/root/shared-data/tz-demo-app --build-arg NODE_ENV=development \
--destination=harbor.harbor.okestro-k8s.okestro.me/okestro-k8s/kaniko-executor:v1.7.0-debug \
--use-new-run --cleanup --force --skip-tls-verify



cat <<EOF > /etc/docker/daemon.json
{
  "insecure-registries":["harbor.harbor.okestro-k8s.okestro.me"]
}
EOF

systemctl restart docker

echo "Harbor12345" | docker login harbor.harbor.okestro-k8s.okestro.me -u admin --password-stdin

#kubectl delete secret harbor-registry-secret -n jenkins
#kubectl create secret generic harbor-registry-secret \
#    --from-file=.dockerconfigjson=/root/.docker/config.json \
#    --type=kubernetes.io/dockerconfigjson -n jenkins


kubectl create secret docker-registry regsecret -n jenkins \
    --docker-server=harbor.harbor.okestro-k8s.okestro.me \
    --docker-username=admin \
    --docker-password=Harbor12345 \
    --docker-email=topzone8713@gmail.com

exit 0

#docker login -u topzone8713
docker build -t topzone8713/kaniko-executor:v1.7.0-debug .
#docker push topzone8713/kaniko-executor:v1.7.0-debug

kubectl delete -f ubuntu.yaml -n jenkins
kubectl apply -f ubuntu.yaml -n jenkins

apt-get update && \
    apt-get -qy full-upgrade vim && \
    apt-get install -qy curl docker-compose && \
    apt-get install -qy --no-install-recommends apt-utils && \
    curl -sSL https://get.docker.com/ | sh

cat <<EOF > /etc/docker/daemon.json
{
  "insecure-registries":["harbor.harbor.okestro-k8s.okestro.me"]
}
EOF



