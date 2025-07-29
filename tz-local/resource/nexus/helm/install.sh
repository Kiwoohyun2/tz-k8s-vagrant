#!/usr/bin/env bash

source /root/.bashrc
function prop { key="${2}=" file="/root/.k8s/${1}" rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); [[ -z "$rslt" ]] && key="${2} = " && rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); rslt=$(echo "$rslt" | tr -d '\n' | tr -d '\r'); echo "$rslt"; }
#bash /vagrant/tz-local/resource/nexus/helm/install.sh
cd /vagrant/tz-local/resource/nexus/helm

k8s_domain=$(prop 'project' 'domain')
k8s_project=$(prop 'project' 'project')
AWS_REGION=$(prop 'config' 'region')
admin_password=$(prop 'project' 'admin_password')
NS=devops

helm repo add oteemocharts https://oteemo.github.io/charts
helm search repo oteemocharts/sonatype-nexus
helm repo update
helm delete sonatype-nexus -n ${NS}

cp values.yaml values.yaml_bak
sed -i "s/admin_password/${admin_password}/g" values.yaml_bak

#CM_ARN=$(aws acm list-certificates --query CertificateSummaryList[].[CertificateArn,DomainName] \
#  --certificate-statuses ISSUED --output text | grep "*.${k8s_domain}" | cut -f1 | head -n 1)
#echo "CM_ARN: $CM_ARN"
#sed -i "s|CM_ARN|${CM_ARN}|g" values.yaml_bak

sed -i "s/k8s_project/${k8s_project}/g" values.yaml_bak
sed -i "s/k8s_domain/${k8s_domain}/g" values.yaml_bak
sed -i "s/AWS_REGION/${AWS_REGION}/g" values.yaml_bak
#--reuse-values
helm upgrade --debug --install --reuse-values sonatype-nexus -n ${NS} \
  oteemocharts/sonatype-nexus -f values.yaml_bak  --values="values.yaml_bak"

#k patch deployment/sonatype-nexus -n ${NS} \
# --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/1/env/4", "value": {"name": "NEXUS_DOCKER_HOST", "value": "*" } }]'
#k patch deployment/sonatype-nexus -n ${NS} \
# --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/1/env/5", "value": {"name": "NEXUS_HTTP_HOST", "value": "*" } }]'

cp -Rf ingress-nexus.yaml ingress-nexus.yaml_bak
sed -i "s/k8s_project/${k8s_project}/g" ingress-nexus.yaml_bak
sed -i "s/k8s_domain/${k8s_domain}/g" ingress-nexus.yaml_bak
sed -i "s/AWS_REGION/${AWS_REGION}/g" ingress-nexus.yaml_bak
k delete -f ingress-nexus.yaml_bak -n ${NS}
k apply -f ingress-nexus.yaml_bak -n ${NS}

helm list --all-namespaces -a

#kubectl run -it busybox --image=alpine:3.6 -n ${NS} --overrides='{ "spec": { "nodeSelector": { "team": "devops", "environment": "prod" } } }' -- sh
#nc -zv sonatype-nexus.devops.svc.cluster.local 8080

#kubectl -n ${NS} edit svc/sonatype-nexus
#spec:
#  ports:
#    - name: sonatype-nexus
#      protocol: TCP
#      port: 8080
#      targetPort: 8080
#      nodePort: 32647
#    - name: sonatype-docker
#      protocol: TCP
#      port: 5003
#      targetPort: 5003
#      nodePort: 32648

DOCKER_ELB=docker.default.${k8s_project}.${k8s_domain}
echo "
##[ Nexus ]##########################################################
- url: http://nexus.default.${k8s_project}.${k8s_domain}/
- admin / admin123

http://nexus.default.${k8s_project}.${k8s_domain}/#admin/repository/blobstores

Create blob store
  docker-hosted   # s3: devops-nexus-okestro-k8s
  docker-hub      # s3: devops-nexus-hub-okestro-k8s

http://nexus.default.${k8s_project}.${k8s_domain}/#admin/repository/repositories
  Repositories > Select Recipe > Create repository: docker (hosted)
  name: docker-hosted
  http: 5003
  https: 5443
  Enable Docker V1 API: checked
  Blob store: docker-hosted

Repositories > Select Recipe > Create repository: docker (proxy)
  name: docker-hub
  Enable Docker V1 API: checked
  Remote storage: https://registry-1.docker.io
  select Use Docker Hub
  Blob store: docker-hub

http://nexus.default.${k8s_project}.${k8s_domain}/#admin/security/realms
  add Docker Bearer Token Realm Active

http://nexus.default.${k8s_project}.${k8s_domain}/#admin/security/sslcertificates
  load certificate from server
  docker.default.okestro-k8s.okestro.me


DOCKER_ELB=nexus.okestro-k8s.okestro.me:5433
docker login -u admin -p "${admin_password}" ${DOCKER_ELB}
docker pull busybox
RMI=`docker images -a | grep busybox | awk '{print $3}' | head -n 1`
docker tag $RMI docker.default.${k8s_project}.${k8s_domain}/busybox:v20201225
docker push docker.default.${k8s_project}.${k8s_domain}/busybox:v20201225
#######################################################################
" >> /vagrant/info
cat /vagrant/info

exit 0

docker login -u admin https://docker.default.okestro-k8s.okestro.me --password-stdin admin123


https://nexus.okestro-k8s.okestro.me/#admin/security/privileges

docker login nexus.okestro-k8s.okestro.me:5433

Get "https://xxx/v2/": dial tcp: lookup xxx on 127.0.0.53:53: no such host

docker.okestro-k8s.okestro.me