#!/usr/bin/env bash

# https://www.joinc.co.kr/w/man/12/Kafka/exactlyonce


shopt -s expand_aliases

alias k='kubectl --kubeconfig ~/.kube/config'

# install kafka schema-registry
cd /vagrant/kafka
git clone https://github.com/confluentinc/cp-helm-charts.git
cp -Rf /vagrant/kafka/cp-helm-charts/charts/cp-schema-registry/values.yaml /vagrant/kafka/cp-helm-charts/charts/schema-registry-values.yaml
sudo sed -i "s|bootstrapServers: \"\"|bootstrapServers: \"kafka-headless:9092\"|g" /vagrant/kafka/cp-helm-charts/charts/schema-registry-values.yaml
helm uninstall my-schema -n kafka
cd /vagrant/kafka/cp-helm-charts/charts
helm install my-schema -f schema-registry-values.yaml cp-schema-registry -n kafka
k get all -n kafka

cp -Rf /vagrant/kafka/cp-helm-charts/charts/cp-kafka-connect/values.yaml /vagrant/kafka/cp-helm-charts/charts/my-connect-values.yaml
sudo sed -i "s|bootstrapServers: \"\"|bootstrapServers: \"kafka-headless:9092\"|g" /vagrant/kafka/cp-helm-charts/charts/my-connect-values.yaml
sudo sed -i "s|url: \"\"|url: \"http://my-schema-cp-schema-registry:8081\"|g" /vagrant/kafka/cp-helm-charts/charts/my-connect-values.yaml
sudo sed -i "s|enabled: true|enabled: false|g" /vagrant/kafka/cp-helm-charts/charts/my-connect-values.yaml

helm uninstall my-connect -n kafka
cd /vagrant/kafka/cp-helm-charts/charts
helm install my-connect -f my-connect-values.yaml cp-kafka-connect -n kafka

#https://tsuyoshiushio.medium.com/local-kafka-cluster-on-kubernetes-on-your-pc-in-5-minutes-651a2ff4dcde
helm repo add confluentinc https://confluentinc.github.io/cp-helm-charts/
helm repo update
helm install my-confluent confluentinc/cp-helm-charts -f ./values.yaml

# install kafka connector
#k delete -f /vagrant/tz-local/resource/kafka/connector/kafka-connector-source.yaml -n kafka
k apply -f /vagrant/tz-local/resource/kafka/connector/kafka-connector-source.yaml -n kafka
#k delete -f /vagrant/tz-local/resource/kafka/connector/kafka-connector-target.yaml -n kafka
k apply -f /vagrant/tz-local/resource/kafka/connector/kafka-connector-target.yaml -n kafka

k get deployment.apps/my-connect-cp-kafka-connect -n kafka -o yaml > /vagrant/tz-local/resource/kafka/connector/my-connect-cp-kafka-connect.yaml
sudo sed -i "s|value: \"3\"|value: \"1\"|g" /vagrant/tz-local/resource/kafka/connector/my-connect-cp-kafka-connect.yaml
k delete deployment.apps/my-connect-cp-kafka-connect -n kafka
k apply -f /vagrant/tz-local/resource/kafka/connector/my-connect-cp-kafka-connect.yaml -n kafka

k get all -n kafka

k patch svc `k get svc -n kafka | grep 'zookeeper ' | awk '{print $1}'` --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/0/nodePort","value":32181}]' -n kafka
k patch svc `k get svc -n kafka | grep 'kafka ' | awk '{print $1}'` --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/0/nodePort","value":30092}]' -n kafka
k patch svc `k get svc -n kafka | grep 'postgres-source' | awk '{print $1}'` --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/0/nodePort","value":30432}]' -n kafka

# 3: Test Apache Kafka
echo "
##[ Kafka connector ]##########################################################

# from source db
k exec -it `k get pod -n kafka | grep postgres-source | awk '{print $1}'` -n kafka -- sh
psql -d postgres -U postgres
# admin1234!
postgres-# \dn  # schema
postgres-# \l   # databases
postgres-# \c postgres postgres   # connect to a db

CREATE TABLE test_1 (
	user_id serial PRIMARY KEY,
	username VARCHAR ( 50 ) UNIQUE NOT NULL,
	password VARCHAR ( 50 ) NOT NULL,
	email VARCHAR ( 255 ) UNIQUE NOT NULL,
	created_on TIMESTAMP NOT NULL,
        last_login TIMESTAMP
);

postgres-# \dt

postgres-# \d test_1

INSERT INTO test_1(user_id, username, password, email, created_on)
VALUES (2, "doohee321", "passwd", "dhong@gmail.com", "20120-12-30 19:10:25-07")
RETURNING *;

SELECT * FROM test_1;
#\q {enter}

# from target db
k exec -it `k get pod -n kafka | grep postgres-target | awk '{print $1}'` -n kafka -- sh
psql -d postgres -U postgres

#######################################################################
' >> /vagrant/info
cat /vagrant/info
exit 0


#https://github.com/lensesio/kafka-topics-ui

helm repo add kafka-topics-ui https://dhiatn.github.io/helm-kafka-topics-ui -n kafka
helm install kafka-topics-ui -n kafka kafka-topics-ui/kafka-topics-ui -n kafka

export SERVICE_IP=$(kubectl get svc --namespace kafka kafka-topics-ui -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo http://$SERVICE_IP:80

service/kafka                          ClusterIP      10.109.195.97    <none>        9092/TCP                     21h
service/zookeeper                      ClusterIP      10.107.241.2     <none>        2181/TCP,2888/TCP,3888/TCP   20h
service/postgres-source                ClusterIP      10.108.186.12    <none>        5432/TCP                     11m

telnet 192.168.0.100 32181

