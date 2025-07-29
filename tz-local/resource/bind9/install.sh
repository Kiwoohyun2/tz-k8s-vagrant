#!/usr/bin/env bash

source /root/.bashrc
# bash /vagrant/tz-local/resource/bind9/install.sh
cd /vagrant/tz-local/resource/bind9

#set -x
shopt -s expand_aliases

k8s_project=hyper-k8s  #$(prop 'project' 'project')
k8s_domain=$(prop 'project' 'domain')
admin_password=$(prop 'project' 'admin_password')
github_token=$(prop 'project' 'github_token')
basic_password=$(prop 'project' 'basic_password')

#echo "nameserver 8.8.8.8" >> /etc/resolv.conf

cat <<EOF | sudo tee /etc/resolv.conf
search .
nameserver 192.168.0.100
nameserver 127.0.0.53
nameserver 8.8.8.8
options edns0 trust-ad
EOF

sudo apt install bind9 bind9utils bind9-doc -y

sed -i "s/-u bind/-u bind -4/g" /etc/default/named

cp /etc/bind/named.conf.options /etc/bind/named.conf.options.ori
echo "
acl \"trusted\" {
	192.168.0.100;    # host ip
};

options {
	directory \"/var/cache/bind\";

	recursion yes;                 # enables recursive queries
	allow-recursion { trusted; };  # allows recursive queries from trusted clients
	listen-on { 192.168.0.100; };   # ns1 private IP address - listen on private network only
	allow-transfer { none; };      # disable zone transfers by default

#	forwarders {
#	    8.8.8.8;
#	    8.8.4.4;
#	};

	dnssec-validation auto;
	listen-on-v6 { any; };
};
" > /etc/bind/named.conf.options

sudo cp /etc/bind/named.conf /etc/bind/named.conf.orig
sudo cp /etc/bind/named.conf.local /etc/bind/named.conf.local.orig
cat <<EOF | sudo tee /etc/bind/named.conf.local
zone "t1zone.com" {
        type primary;
        file "/etc/bind/zones/db.t1zone.com";
        allow-transfer { 192.168.0.100; };
};
EOF

mkdir /etc/bind/zones
#sudo cp /etc/bind/db.local /etc/bind/zones/db.t1zone.com

cat <<EOF | sudo tee /etc/bind/zones/db.t1zone.com
\$TTL 86400;
@	IN	SOA	t1zone.com. root.t1zone.com. (
			      3		; Serial
			 604800		; Refresh
			  86400		; Retry
			2419200		; Expire
			 604800 )	; Negative Cache TTL
;
@	IN	NS	t1zone.com.
@	IN	AAAA	::1
* IN	A 192.168.0.27
* IN	A 192.168.0.36
;
ns1.t1zone.com.          IN      A       192.168.0.100
host2.t1zone.com.          IN      A       192.168.0.91
www           IN      CNAME   t1zone.com.
EOF

named-checkzone t1zone.com /etc/bind/zones/db.t1zone.com

service systemd-resolved stop
sudo systemctl restart bind9
#service bind9 status

dig @192.168.0.100 host2.t1zone.com
dig host2.t1zone.com
dig main.devops.eks-main-t.t1zone.com
dig consul.default.home-k8s.t1zone.com

dig @192.168.0.100 consul.default.home-k8s.t1zone.com
dig @192.168.0.100 test.default.home-k8s.t1zone.com


#dig google.com

exit 0



