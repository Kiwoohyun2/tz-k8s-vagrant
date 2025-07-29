#!/bin/bash

export MSYS_NO_PATHCONV=1
export tz_project=devops-utils

#set -x

WORKING_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd ${WORKING_DIR}
echo "WORKING_DIR: ${WORKING_DIR}"

if [[ "$1" == "help" || "$1" == "-h" || "$1" == "/help" ]]; then
cat <<EOF
  - bash bootstrap.sh
      If it's from scratch, it means "vagrant up" else "vagrant reload"
  - bash bootstrap.sh halt
      "vagrant halt"
  - bash bootstrap.sh reload
      "vagrant reload"
  - bash bootstrap.sh provision
      "run kubespray.sh and other scripts"
  - bash bootstrap.sh status
      "vagrant status"
  - bash bootstrap.sh save
      "vagrant save snapshot xxx"
  - bash bootstrap.sh restore xxx
      "vagrant restore snapshot xxx"
  - bash bootstrap.sh delete xxx
      "vagrant restore delete xxx"
  - bash bootstrap.sh ssh
      "vagrant ssh kube-master"
  - bash bootstrap.sh remove
      "vagrant destroy -f"
EOF
exit 0
fi

PROVISION=''
if [[ "$1" == "halt" ]]; then
  echo "vagrant halt"
  vagrant halt
  exit 0
elif [[ "$1" == "status" ]]; then
  echo "vagrant status"
  vagrant status
  exit 0
elif [[ "$1" == "ssh" ]]; then
  echo "vagrant ssh kube-master"
  vagrant ssh kube-master
  exit 0
elif [[ "$1" == "provision" ]]; then
  PROVISION='y'
elif [[ "$1" == "remove" ]]; then
  echo "vagrant destroy -f"
  vagrant destroy -f
  git checkout Vagrantfile
  rm -Rf info
  exit 0
elif [[ "$1" == "docker" ]]; then
  DOCKER_NAME=`docker ps | grep docker-${tz_project} | awk '{print $1}'`
  echo "======= DOCKER_NAME: ${DOCKER_NAME}"
  if [[ "${DOCKER_NAME}" == "" ]]; then
    bash tz-local/docker/install.sh
  fi
  if [[ "$1" == "sh" ]]; then
    docker exec -it `docker ps | grep docker-${tz_project} | awk '{print $1}'` bash
    exit 0
  fi

#  echo docker exec -it ${DOCKER_NAME} bash /vagrant/tz-local/docker/init2.sh
#  docker exec -it ${DOCKER_NAME} bash /vagrant/tz-local/docker/init2.sh
fi

if [ ! -f info ]; then
  echo -n "Do you want to make a jenkins on k8s in Vagrant Master / Slave? (M/S) "
  read A_ENV
else
  A_ENV=`cat Vagrantfile | grep 'kube-master'`
  if [[ "${A_ENV}" != "" ]]; then
    A_ENV="M"
  else
    A_ENV="S"
  fi
fi

MYKEY=tz_rsa
if [ ! -f .ssh/${MYKEY} ]; then
  mkdir -p .ssh \
    && cd .ssh \
    && ssh-keygen -t rsa -C ${MYKEY} -P "" -f ${MYKEY} -q
  echo "Make ssh key files: ${MYKEY}"
else
  echo "Use existing ssh key files: ${MYKEY}"
fi

cp -Rf Vagrantfile Vagrantfile.bak
if [[ "${1}" == "save" || "${1}" == "restore" || "${1}" == "delete" || "${1}" == "list" ]]; then
  EVENT=${1}
else
  EVENT=`vagrant status | grep -E 'kube-master|kube-slave-1' | grep 'not created'`
  if [[ "${EVENT}" != "" ]]; then
    EVENT='up'
  else
    EVENT='reload'
  fi
fi
echo "EVENT: ${EVENT}, Type: ${A_ENV}, PROVISION: ${PROVISION}"

if [[ "${A_ENV}" == "M" ]]; then
  cp -Rf ./scripts/local/Vagrantfile Vagrantfile
  PROJECTS=(kube-master kube-node-1 kube-node-2)
elif [[ "${A_ENV}" == "S" ]]; then
  cp -Rf ./scripts/local/Vagrantfile_slave Vagrantfile
  PROJECTS=(kube-slave-1 kube-slave-2 kube-slave-3)
fi

if [[ "${EVENT}" == "up" ]]; then
  echo "- PC Type: ${A_ENV}" > info
  echo "##################################################################################"
  echo 'vagrant ${EVENT} --provider=virtualbox'
  echo "##################################################################################"
  sleep 5
  vagrant ${EVENT} --provider=virtualbox
  if [[ "${A_ENV}" == "M" ]]; then
    echo "##################################################################################"
    echo 'vagrant ssh kube-master -- -t "sudo bash /vagrant/scripts/local/kubespray.sh"'
    echo "##################################################################################"
    sleep 5
    vagrant ssh kube-master -- -t "sudo bash /vagrant/scripts/local/kubespray.sh"
    echo "##################################################################################"
    echo 'vagrant ssh kube-master -- -t "sudo bash /vagrant/scripts/local/master_01.sh"'
    echo "##################################################################################"
    sleep 5
    vagrant ssh kube-master -- -t "sudo bash /vagrant/scripts/local/master_01.sh"
  fi
elif [[ "${EVENT}" == "save" || "${EVENT}" == "restore" || "${EVENT}" == "delete" || "${EVENT}" == "list" ]]; then
  if [[ "${EVENT}" == "save" ]]; then
    item=$(date +"%Y%m%d-%H%M%S")
    echo vagrant snapshot ${EVENT} ${item}
    vagrant snapshot ${EVENT} ${item}
  elif [[ "${EVENT}" == "restore" || "${EVENT}" == "delete" ]]; then
    echo vagrant snapshot ${EVENT} ${2}
    vagrant snapshot ${EVENT} ${2}
  fi
  if [[ "${EVENT}" != "delete" ]]; then
    echo vagrant snapshot list
    vagrant snapshot list
  fi
  exit 0
else
  if [[ "${PROVISION}" == "y" ]]; then
    if [[ "${A_ENV}" == "M" ]]; then
      echo "##################################################################################"
      echo 'vagrant ssh kube-master -- -t "sudo bash /vagrant/scripts/local/kubespray.sh"'
      echo "##################################################################################"
      sleep 5
      vagrant ssh kube-master -- -t "sudo bash /vagrant/scripts/local/kubespray.sh"
      echo "##################################################################################"
      echo 'vagrant ssh kube-master -- -t "sudo bash /vagrant/scripts/local/master_01.sh"'
      echo "##################################################################################"
      sleep 5
      vagrant ssh kube-master -- -t "sudo bash /vagrant/scripts/local/master_01.sh"
    fi
  else
    sleep 5
    echo "##################################################################################"
    echo "vagrant ${EVENT}"
    echo "##################################################################################"
    vagrant ${EVENT}
  fi
fi

#vagrant kube-master -c "ifconfig" | grep eth1 -A 1 | tail -n 1 | awk '{print $2}'

for item in "${PROJECTS[@]}"; do
  IP=`vagrant ssh ${item} -c "ifconfig" | grep eth1 -A 1 | tail -n 1 | awk '{print $2}'`
  echo ${item} ansible_host=${IP} ip=${IP} ansible_user=root ansible_ssh_private_key_file=/root/.ssh/tz_rsa ansible_ssh_extra_args='-o StrictHostKeyChecking=no' ansible_port=22 >> info
done
for item in "${PROJECTS[@]}"; do
  IP=`vagrant ssh ${item} -c "ifconfig" | grep eth1 -A 1 | tail -n 1 | awk '{print $2}'`
  echo ${IP}   ${item} >> info
done

cat info

exit 0

# install in docker
export docker_user="Kiwoohyun2"
bash /vagrant/tz-local/docker/init2.sh

# remove all resources
docker exec -it ${DOCKER_NAME} bash
bash /vagrant/scripts/k8s_remove_all.sh
bash /vagrant/scripts/k8s_remove_all.sh cleanTfFiles

#docker container stop $(docker container ls -a -q) && docker system prune -a -f --volumes
