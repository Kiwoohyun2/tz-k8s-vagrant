#!/usr/bin/env bash

cd tz-local/docker

export docker_user="Kiwoohyun2"
export k8s_project=okestro-k8s
export k8s_domain=okestro.me
export tz_project=devops-utils2

dockerhub_id=${docker_user}
#dockerhub_id=$(prop 'project' 'dockerhub_id')
dockerhub_password=$(prop 'project' 'dockerhub_password')
docker_url=$(prop 'project' 'docker_url')
#docker_url=index.docker.io
docker login -u="${dockerhub_id}" -p="${dockerhub_password}"

TAG=${docker_user}/${tz_project}:latest

cp -Rf docker-compose.yml docker-compose.yml_bak
sed -ie "s|tz-main|${TAG}|g" docker-compose.yml_bak
sed -ie "s|tz_main|${tz_project}|g" docker-compose.yml_bak
docker-compose -f docker-compose.yml_bak build
docker-compose -f docker-compose.yml_bak up -d
#docker-compose -f docker-compose.yml_bak down

docker exec -it `docker ps | grep docker-${tz_project} | awk '{print $1}'` bash
export k8s_project=okestro-k8s
bash /vagrant/tz-local/docker/init2.sh

exit 0
