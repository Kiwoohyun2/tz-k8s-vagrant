#!/usr/bin/env bash

source /root/.bashrc
function prop { key="${2}=" file="/root/.k8s/${1}" rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); [[ -z "$rslt" ]] && key="${2} = " && rslt=$(grep "${3:-}" "$file" -A 10 | grep "$key" | head -n 1 | cut -d '=' -f2 | sed 's/ //g'); rslt=$(echo "$rslt" | tr -d '\n' | tr -d '\r'); echo "$rslt"; }
#bash /vagrant/tz-local/resource/mysql/install.sh
cd /vagrant/tz-local/resource/mysql/bastion

kubectl cp devops-dev/mysql-5d94bc4676-22xp9:tmp/myoutput1.txt /vagrant/tz-local/resource/mysql/bastion/myoutput.txt

#set -x
shopt -s expand_aliases
alias k='kubectl --kubeconfig ~/.kube/config'

k8s_project=$(prop 'project' 'project')
NS=devops-dev

# 1. make ubuntu pod as bastion
kubectl -n devops-dev apply -f ubuntu.yaml

apt-get update -y
apt-get install -y curl wget jq unzip netcat apt-transport-https gnupg2 redis-tools mysql-client

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install --update

curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator_0.5.9_linux_amd64 && \
    chmod +x aws-iam-authenticator && \
    sudo mv aws-iam-authenticator /usr/local/bin

curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.23.6/bin/linux/amd64/kubectl && \
    chmod 777 kubectl && \
    mv kubectl /usr/bin/kubectl

# 2. upload aws, k8s credentials
kubectl -n devops-dev cp /root/.k8s devops-dev/bastion:/root/.k8s
kubectl -n devops-dev cp /root/.kube devops-dev/bastion:/root/.kube
kubectl -n devops-dev cp /root/.ssh devops-dev/bastion:/root/.ssh

# 3. run ddl from bastion
#MYSQL_HOST=$(kubectl -n devops-dev get svc devops-mysql | tail -n 1 | awk '{print $4}')
MYSQL_HOST=devops-mysql.devops-dev.svc.cluster.local
echo ${MYSQL_HOST}
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD=$(kubectl -n devops-dev get secret devops-mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode; echo)
echo $MYSQL_ROOT_PASSWORD
mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD} -e "SHOW databases;"

mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD}

MYSQL_HOST=devops-prod.cluster-cc6byzimkqxb.ap-northeast-2.rds.amazonaws.com
mysql -h devops-prod.cluster-cc6byzimkqxb.ap-northeast-2.rds.amazonaws.com -P 3306 \
  --user=root -p'xxxx'

show databases;
use mysql;
#SET PASSWORD FOR 'root'@'localhost' = PASSWORD('xxxxx');
#SET PASSWORD FOR 'root'@'*' = PASSWORD('xxxxx');
DROP USER 'topzone'@'%';
CREATE USER 'topzone'@'%' IDENTIFIED BY 'xxxxx';
GRANT ALL PRIVILEGES ON *.* to 'topzone'@'%' IDENTIFIED BY 'xxxxx' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON topzone.* to 'topzone'@'%' IDENTIFIED BY 'xxxxx' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON `%`.* TO topzone@'%' IDENTIFIED BY 'xxxxx' WITH GRANT OPTION;
SHOW GRANTS for topzone;

GRANT USAGE ON *.* TO 'topzone'@'%';
#GRANT ALL PRIVILEGES ON *.* TO 'topzone'@'%';
GRANT ALL PRIVILEGES ON topzone.* to 'topzone'@'%' IDENTIFIED BY 'xxxxx' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON Admin.* TO 'topzone'@'%' IDENTIFIED BY 'xxxxx' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON Asset.* TO 'topzone'@'%' IDENTIFIED BY 'xxxxx' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON Service.* TO 'topzone'@'%' IDENTIFIED BY 'xxxxx' WITH GRANT OPTION;

mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=topzone -p'xxxxx'

#DROP database topzone;
CREATE database topzone;
CREATE database Admin;
CREATE database Asset;
CREATE database Service;

GRANT ALL PRIVILEGES ON Admin.* TO 'topzone'@'%';
GRANT ALL PRIVILEGES ON topzone.* TO 'topzone'@'%';
GRANT ALL PRIVILEGES ON Asset.* TO 'topzone'@'%';
GRANT ALL PRIVILEGES ON Service.* TO 'topzone'@'%';
SHOW GRANTS for topzone;

#REVOKE ALL PRIVILEGES on topzone.* from topzone;
#REVOKE ALL PRIVILEGES on Admin.* from topzone;
#REVOKE USAGE ON *.* from topzone;

FLUSH PRIVILEGES;

#GRANT ALL PRIVILEGES ON topzone.* to 'topzone'@'localhost' IDENTIFIED BY 'xxxxx';
#GRANT ALL PRIVILEGES ON topzone.* to 'topzone'@'%' IDENTIFIED BY 'xxxxx';
#CREATE database topzone;

#mysql -h devops-prod.cluster-cc6byzimkqxb.ap-northeast-2.rds.amazonaws.com -P 3306 --user=root -p'w14YE*6u+kx~0b[eQikOKwEjyt1%'
#mysql -h devops-prod.cluster-cc6byzimkqxb.ap-northeast-2.rds.amazonaws.com -P 3306 --protocol tcp --user=topzone -pxxxxx

#ssh -i ~/.ssh/Kiwoohyun2 ubuntu@3.35.207.182 -L 3306:devops-prod.cluster-cc6byzimkqxb.ap-northeast-2.rds.amazonaws.com:3306
#mysql -h localhost -P 3306 --protocol tcp --user=topzone -p'xxxxx'

# 5. dump topzone mysql
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD='verysecret'
#mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --protocol tcp --user=topzone -p${MYSQL_ROOT_PASSWORD}
mysqldump --column-statistics=0 --no-tablespaces -h ${MYSQL_HOST} --user=admin -p${MYSQL_ROOT_PASSWORD} --add-drop-table app > /root/topzone.sql
#kubectl -n devops-dev cp devops-dev/bastion:/root/topzone.sql topzone.sql
#kubectl -n devops-dev cp topzone.sql devops-dev/devops-bastion:/root/topzone.sql

# 6. import topzone mysql
kubectl cp monitoring/bastion:topzone.sql topzone.sql
kubectl cp monitoring/bastion:Admin.sql Admin.sql
kubectl cp monitoring/bastion:Asset.sql Asset.sql
kubectl cp monitoring/bastion:Service.sql Service.sql

#MYSQL_HOST=topzone2-prod-private-2.c01spz81v11d.ap-northeast-2.rds.amazonaws.com
#MYSQL_HOST=devops-mysql.devops-dev.svc.cluster.local
MYSQL_HOST=mysql.devops.okestro.me
MYSQL_PORT=3306
MYSQL_PASSWORD='xxxxx'
mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --protocol tcp --user=topzone -p${MYSQL_PASSWORD}

#https://bobcares.com/blog/aws-rds-mysql-super-privilege/
#default-aurora-mysql57
#  log_bin_trust_function_creators	0, 1

mysql -h devops-prod.cluster-cc6byzimkqxb.ap-northeast-2.rds.amazonaws.com -P 3306   --user=root -p'xxxx'
use mysql;
DROP USER 'topzone'@'%';
CREATE USER 'topzone'@'%' IDENTIFIED BY 'xxxxxx';
GRANT ALL PRIVILEGES ON *.* to 'topzone'@'%' IDENTIFIED BY 'xxxxxx';

mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} --protocol tcp --user=topzone -p${MYSQL_PASSWORD} < topzone.sql

mysql topzone --user=topzone --password='xxxxxx' --host=${MYSQL_HOST} < topzone.sql

# import data
SET autocommit=0;
SET unique_checks=0;
SET foreign_key_checks=0;
COMMIT;

mysql topzone --user=topzone --password=${MYSQL_PASSWORD} --host=${MYSQL_HOST} < topzone.sql
mysql Admin --user=topzone --password=${MYSQL_PASSWORD} --host=${MYSQL_HOST} < Admin.sql
mysql Asset --user=topzone --password=${MYSQL_PASSWORD} --host=${MYSQL_HOST} < Asset.sql
mysql Service --user=topzone --password=${MYSQL_PASSWORD} --host=${MYSQL_HOST} < Service.sql

SET autocommit=1;
SET unique_checks=1;
SET foreign_key_checks=1;
COMMIT;

#SET sql_safe_updates=1, sql_select_limit=100000, max_join_size=3000000;

exit 0

#test_env_variable='arn:aws:secretsmanager:ap-northeast-2:336363860990:secret:rds!cluster-a4d398a6-ce84-42b2-ae72-53818a97a318-s1o6pL'
#aws secretsmanager get-secret-value --secret-id $test_env_variable --query "SecretString"

#mysql -h devops-prod.cluster-cc6byzimkqxb.ap-northeast-2.rds.amazonaws.com -P 3306

MYSQL_PORT=3306
MYSQL_NAME=topzone
MYSQL_USER=topzone
MYSQL_HOST=test-topzone-db.cc6byzimkqxb.ap-northeast-2.rds.amazonaws.com
MYSQL_ROOT_PASSWORD=4RRE1oFCWaPHzQee

mysql topzone --user=root --password=${MYSQL_ROOT_PASSWORD} --host=${MYSQL_HOST}

mysqldump --column-statistics=0 -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD} --add-drop-table topzone > topzone.sql
mysqldump --column-statistics=0 -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD} --add-drop-table Admin > Admin.sql
mysqldump --column-statistics=0 -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD} --add-drop-table Asset > Asset.sql
mysqldump --column-statistics=0 -h ${MYSQL_HOST} -P ${MYSQL_PORT} --user=root -p${MYSQL_ROOT_PASSWORD} --add-drop-table Service > Service.sql

MYSQL_HOST=devops-prod.cluster-cc6byzimkqxb.ap-northeast-2.rds.amazonaws.com
MYSQL_HOST=mysql.devops.okestro.me
MYSQL_PORT=3306
MYSQL_USER=topzone
MYSQL_PASSWORD='xxx'
MYSQL_ROOT_PASSWORD='xxxx'
mysql -h ${MYSQL_HOST} -P 3306 --user=topzone -p${MYSQL_PASSWORD}
mysql -h ${MYSQL_HOST} -P 3306 --user=root -p${MYSQL_ROOT_PASSWORD}

show processlist;
show status where `variable_name` = 'Threads_connected';
SHOW STATUS WHERE `variable_name` = 'Max_used_connections';

