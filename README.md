# tz-k8s-vagrant

It supports two version of k8s installation in terraform or local VMs.
to project root directory. 

![Architecture1](./resource/tz-k8s-vagrant-env.png)
![Architecture2](./resource/tz-k8s-vagrant-env1.png)

## -. Features 
```
    -. Prep a build environment
    -. Install k8s master (kubespray.sh)
    -. Add k8s slave nodes (kubespray_add.sh)
    -. Install other applications (k8s_addtion.sh)
    -. Setup jenkins
    -. Build a demo application in jenkins
    -. Deploy the app to k8s 
```

## -. Prep a build environment
```
    -. checkout codes
       git clone https://github.com/Kiwoohyun2/tz-k8s-vagrant.git
       cd tz-k8s-vagrant

    -. copy resources like this,
        tz-k8s-vagrant/resources
            project             # change your project name, it'll be a eks cluster name.
            config.json         # dockerhub auth

    -. project infos
    tz-k8s-vagrant/resources/project
    
    ex)
        project=okestro-k8s
        domain=okestro.me     # temporary local domain
        argocd_id=admin
        admin_password=DevOps!323
        basic_password=Soqn!323
        github_id=Kiwoohyun2       # your github_id
        github_token=               # your github token
        docker_url=index.docker.io
        dockerhub_id=Kiwoohyun2    # your dockerhub_id
        dockerhub_password=         # your dockerhub_password
        vault=xxxx                  
    
    -. dockerhub auth 
    tz-k8s-vagrant/resources/config.json
        
        {
            "auths": {
                "https://index.docker.io/v1/": {
                    "username":"Kiwoohyun2",             # your dockerhub_id
                    "password":"xxxx",                  # your dockerhub_password
                    "email":"rltjdgus@gmail.com",      # your email
                    "auth":"xxxxxx"                     # base64 encoding
                }
            },
            "harbor.harbor.okestro-k8s.okestro.me": {
                "username":"admin",
                "password":"Harbor12345",
                "email":"rltjdgus@gmail.com",          # your email
                "auth":"YWRtaW46SGFyYm9yMTIzNDU="
            }
        }
        
       echo -n 'Kiwoohyun2:topzone!323' | base64
        
    -. DHCP IP address check
       Each VMs are supposed to get IP from DHCP server as public_ip in your network area.
       And your master machine and other slave machines should be in the same network area.
       
       vi scripts/local/Vagrantfile
       
          config.vm.define "kube-master" do |master|
            master.vm.box = IMAGE_NAME
            master.vm.network "public_network", bridge: "Realtek Gaming 2.5GbE Family Controller", ip: "192.168.0.100"        => This should be changed to your network
            master.vm.hostname = "kube-master"
            master.vm.provision "shell", :path => File.join(File.dirname(__FILE__),"scripts/local/master.sh"), :args => master.vm.hostname
          end
        
          (1..COUNTER).each do |i|
            config.vm.define "kube-node-#{i}" do |node|
                node.vm.box = IMAGE_NAME
                node.vm.network "public_network", bridge: "Realtek Gaming 2.5GbE Family Controller", ip: "192.168.0.10#{i}"  => This should be changed to your network
                
       vi scripts/local/Vagrantfile_slave
          config.vm.define "kube-slave-1" do |slave|
            slave.vm.box = IMAGE_NAME
            slave.vm.network "public_network", xip: "192.168.0.110"        => This should be changed to your network
            slave.vm.hostname = "kube-slave"
            slave.vm.provision "shell", :path => File.join(File.dirname(__FILE__),"scripts/local/node.sh"), :args => slave.vm.hostname
          end
        
          (2..COUNTER).each do |i|
            config.vm.define "kube-slave-#{i}" do |node|
                node.vm.box = IMAGE_NAME
                node.vm.network "public_network", ip: "192.168.0.11#{i}"   => This should be changed to your network
                node.vm.hostname = "kube-slave-#{i}"
                node.vm.provision "shell", :path => File.join(File.dirname(__FILE__),"scripts/local/node.sh"), :args => node.vm.hostname
            end
          end      
          
```

## -. Install k8s master (kubespray.sh) on master machine
``` 
    -. Update IPs on inventory.ini for your master machine
        resource/kubespray/inventory.ini           

    -. Install k8s master node        
        bash bootstrap.sh M     # master machine
        # bash bootstrap.sh remove
    
    -. After installing k8s on master machine, check k8s master
        cd tz-k8s-vagrant
        vagrant status
        vagrant ssh kube-master
        sudo su
        kubectl get node
``` 

## -. Add k8s slave nodes (kubespray_add.sh)
``` 
    Copy master machine's .ssh folder to each slave machines for ssh key files
    - From: master machine
        tz-k8s-vagrant/.ssh
    - To: slave machines
        tz-k8s-vagrant/.ssh
    
    -. Update IPs on inventory.ini for your slave machine
        resource/kubespray/inventory_add.ini           

    -. Install k8s slave node        
        bash bootstrap.sh S     # slave machine
        # bash bootstrap.sh remove
    
    When slave nodes (Vagrant VMs) are up, run kubespray_add.sh on master machine.
    -. Check slave nodes' IPs
        cat tz-k8s-vagrant/info
    -. Add slave nodes' IPs on inventory_add.ini of master machine.
        tz-k8s-vagrant/resource/kubespray/inventory_add.ini
    -. Check network access on master machine.
        vagrant ssh kube-master
        sudo su
        cd /vagrant
        ansible all -i resource/kubespray/inventory_add.ini -m ping -u root    
        It should be like this,
        kube-slave-1 | SUCCESS => {
            "changed": false,
            "ping": "pong"
        }    
        ...
    -. Add k8s slave nodes on Master Node
        bash /vagrant/scripts/local/kubespray_add.sh
``` 

## -. Install other applications (k8s_addtion.sh)
``` 
    -. Set temporary domains
        vagrant ssh kube-master
        sudo su
        vi /etc/hosts
        ex) 192.168.0.200 is my ingress-nginx's EXTERNAL-IP
            kubectl get svc -n default | grep ingress-nginx-controller        
        
            192.168.0.200   test.default.okestro-k8s.okestro.me consul.default.okestro-k8s.okestro.me vault.default.okestro-k8s.okestro.me
            192.168.0.200   consul-server.default.okestro-k8s.okestro.me argocd.default.okestro-k8s.okestro.me
            192.168.0.200   jenkins.default.okestro-k8s.okestro.me harbor.harbor.okestro-k8s.okestro.me
            192.168.0.200   grafana.default.okestro-k8s.okestro.me prometheus.default.okestro-k8s.okestro.me alertmanager.default.okestro-k8s.okestro.me
            192.168.0.200   vagrant-demo-app.devops-dev.okestro-k8s.okestro.me

    -. After installing k8s on all machines,
        bash /vagrant/scripts/k8s_addtion.sh
``` 

## -. Build Demo app
### cf) demo app: https://github.com/Kiwoohyun2/tz-demo-app
```
    - build a K8S in local topzone VMs
        topzone -> VMs -> k8s -> monitoring -> jenkins -> demo-app build
```

## -. Remove VMs
```
    cd tz-k8s-vagrant
    bash bootstrap.sh remove
```

## * install kubectl in macbook 
### cf) https://kubernetes.io/docs/tasks/tools/install-kubectl/
``` 
    brew install kubectl
    mkdir -p ~/.kube
    cp tz-k8s-vagrant/config ~/.kube/config
    kubectl get nodes
```


