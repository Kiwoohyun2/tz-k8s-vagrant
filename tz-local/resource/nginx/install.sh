#!/usr/bin/env bash

#https://www.nginx.com/blog/using-free-ssltls-certificates-from-lets-encrypt-with-nginx/

source /root/.bashrc
cd /vagrant/tz-local/resource/nginx

NS=$1
if [[ "${NS}" == "" ]]; then
  NS=default
fi
k8s_project=$2
if [[ "${k8s_project}" == "" ]]; then
  k8s_project=$(prop 'project' 'project')
fi
k8s_domain=$3
if [[ "${k8s_domain}" == "" ]]; then
  k8s_domain=$(prop 'project' 'domain')
fi

#set -x
shopt -s expand_aliases
alias k="kubectl -n ${NS} --kubeconfig ~/.kube/config"

$ apt-get update
$ sudo apt-get install certbot
$ apt-get install python3-certbot-nginx

```
server {
    listen   *:80;
    server_name  alertmanager.shoptools.co.kr;

    location / {
        proxy_pass https://alertmanager.default.hyper-k8s.shoptoolstest.co.kr:14444/;
        proxy_ssl_verify off;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

sudo certbot --nginx -d alertmanager.shoptools.co.kr
sudo certbot --nginx -d grafana.shoptools.co.kr
sudo certbot --nginx -d jenkins.shoptools.co.kr
sudo certbot --nginx -d prometheus.shoptools.co.kr
sudo certbot --nginx -d argocd.shoptools.co.kr
sudo certbot --nginx -d consul-server.shoptools.co.kr
sudo certbot --nginx -d vault.shoptools.co.kr
sudo certbot --nginx -d longhorn.shoptools.co.kr
sudo certbot --nginx -d nexus.okestro-k8s.okestro.me

ln -s /etc/nginx/sites-available/alertmanager alertmanager
ln -s /etc/nginx/sites-available/grafana grafana
ln -s /etc/nginx/sites-available/jenkins jenkins
ln -s /etc/nginx/sites-available/prometheus prometheus
ln -s /etc/nginx/sites-available/consul consul
ln -s /etc/nginx/sites-available/vault vault
ln -s /etc/nginx/sites-available/nexus nexus
ln -s /etc/nginx/sites-available/argocd argocd
ln -s /etc/nginx/sites-available/longhorn longhorn
ln -s /etc/nginx/sites-available/aicreator aicreator

rm -Rf alertmanager grafana jenkins prometheus consul argocd aicreator












