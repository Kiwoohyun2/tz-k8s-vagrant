#!/usr/bin/env bash

sudo apt-get update -y
sudo apt-get install openjdk-8-jdk -y
cd /opt
wget --no-check-certificate https://download.sonatype.com/nexus/3/nexus-3.30.0-01-unix.tar.gz
sudo tar -xvf nexus-3.30.0-01-unix.tar.gz
ln -s nexus-3.30.0-01 nexus

sudo groupadd nexus
sudo useradd -m nexus -g nexus -s /bin/bash
sudo chown -R nexus:nexus /opt/nexus
sudo chown -R nexus:nexus /opt/sonatype-work
sudo sed -i "s|#run_as_user=\"\"|run_as_user=\"root\"|g" /opt/nexus/bin/nexus.rc
#sudo sed -i "s|#application-port=8081|application-port=8081|g" /opt/sonatype-work/nexus3/etc/nexus.properties

#vi /opt/nexus/bin/nexus.vmoptions

echo '
[Unit]
Description=nexus service
After=network.target
[Service]
Type=forking
LimitNOFILE=65536
User=nexus
Group=nexus
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
' > /etc/systemd/system/nexus.service

sudo systemctl enable nexus
sudo systemctl stop nexus
sudo systemctl start nexus
#sudo systemctl restart nexus
#sudo systemctl status nexus

# every client pc needs this setting
echo '
{
        "insecure-registries" : [
          "nexus.okestro-k8s.okestro.me:5000"
        ]
}
' > /etc/docker/daemon.json

sudo service docker restart

echo '
##[ Nexus ]##########################################################
- url: http://nexus.okestro-k8s.okestro.me:8081
- id: admin
- passwd: cat /opt/sonatype-work/nexus3/admin.password

http://nexus.okestro-k8s.okestro.me:8081/#admin/repository/blobstores

Create blob store
  docker-hosted
  docker-hub

http://nexus.okestro-k8s.okestro.me:8081/#admin/repository/repositories
  Repositories > Select Recipe > Create repository: docker (hosted)
  name: docker-hosted
  http: 5000
  Enable Docker V1 API: checked
  Blob store: docker-hosted

Repositories > Select Recipe > Create repository: docker (proxy)
  name: docker-hub
  Enable Docker V1 API: checked
  Remote storage: https://registry-1.docker.io
  select Use Docker Hub
  Blob store: docker-hub

http://nexus.okestro-k8s.okestro.me:8081/#admin/security/realms
  add "Docker Bearer Token Realm" Active

docker login nexus.okestro-k8s.okestro.me:5000

docker pull busybox
RMI=`docker images -a | grep busybox | awk '{print $3}'`
docker tag $RMI nexus.okestro-k8s.okestro.me:5000/busybox:v20201225
docker push nexus.okestro-k8s.okestro.me:5000/busybox:v20201225

http://nexus.okestro-k8s.okestro.me:8081/#browse/browse:docker-hosted

#######################################################################
' >> /vagrant/info
cat /vagrant/info

