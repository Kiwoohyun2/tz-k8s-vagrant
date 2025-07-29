# tz-jenkins

###################################################
## build a jenkins project in EKS
###################################################
```

 - get jenkins url
   => https://jenkins.default.okestro-k8s.okestro.me

 - setting kubernetes plugin
    https://jenkins.default.okestro-k8s.okestro.me/configureClouds/
   - Cloud name: okestro-k8s
   - Kubernetes URL: https://kubernetes.default
   - Kubernetes Namespace: jenkins
    * click Test Connection
   - Jenkins URL: http://jenkins.jenkins.svc.cluster.local
   - Jenkins tunnel: jenkins-agent:50000

 - add secrets  
    - github-token
      1. get github's personal access token:
        https://github.com/settings/tokens
      2. https://jenkins.default.okestro-k8s.okestro.me/credentials/store/system/domain/_/newCredentials
        Kind: Username with password
        Username: ex) rltjdgus@gmail.com
        Password: ex) xxxxxxxxxxxxxxxxxxxxxxxxx
        ID: github-token
        Description: github-token

    - GITHUP_TOKEN
      1. get github's personal access token:
      2. https://jenkins.default.okestro-k8s.okestro.me/credentials/store/system/domain/_/newCredentials
        Kind: Secret text
        Secret: ex) xxxxxxxxxxxxxxxxxxxxxxxxx
        ID: GITHUP_TOKEN
        Description: GITHUP_TOKEN

    - DOCKER_PASSWORD
      1. https://jenkins.default.okestro-k8s.okestro.me/credentials/store/system/domain/_/newCredentials
        Kind: Secret text
        Secret: ex) xxxxxxxxxxxxxxxxxxxxxxxxx
        ID: DOCKER_PASSWORD
        Description: DOCKER_PASSWORD
        
    - VAULT_TOKEN
      1. https://jenkins.default.okestro-k8s.okestro.me/credentials/store/system/domain/_/newCredentials
        Kind: Secret text
        Secret: ex) xxxxxxxxxxxxxxxxxxxxxxxxx
        ID: VAULT_TOKEN
        Description: VAULT_TOKEN
    
    - gmail-smtp
      1. https://jenkins.default.okestro-k8s.okestro.me/credentials/store/system/domain/_/newCredentials
        Kind: Username with password
        Username: ex) rltjdgus@gmail.com
        Password: ex) xxxxxxxxxxxxxxxx
        ID: gmail-smtp
        Description: gmail-smtp

 - settings
    https://jenkins.default.okestro-k8s.okestro.me/manage/configure
    Git plugin
        Global Config user.name Value: Doogee Hong
        Global Config user.email Value: rltjdgus@gmail.com

    - E-mail Notification
        SMTP Server: smtp.gmail.com
        Use SMTP Authentication
            User Name: rltjdgus@gmail.com
            Password: xxxxx  => Google "App password"  // https://myaccount.google.com/apppasswords
        Use SSL: no
        Use TLS: yes
        SMTP Port: 587
        Test configuration by sending test e-mail
        Test e-mail recipient

    - Extended E-mail Notification
        SMTP server: smtp.gmail.com
        SMTP Port: 587
        new credential: gmail-smtp
        Use SSL: false
        Use TLS: yes
```

###################################################
## build a demo app
###################################################

github fork: https://github.com/Kiwoohyun2/tz-demo-app.git
=> https://github.com/Kiwoohyun2/tz-demo-app.git

new project
Enter an item name: tz-demo-app
Select an item type: Pipeline
Pipeline > Definition
Pipeline: Pipeline script from SCM
    SCM: Git
    Repository URL: https://github.com/Kiwoohyun2/tz-demo-app.git
    credentials: github-token
    branch: */vagrant
Script Path: k8s/Jenkinsfile

tz-demo-app/k8s/Jenkinsfile

    environment {
        GITHUP_ID = "Kiwoohyun2"               =>
        GIT_URL = "https://github.com/${GITHUP_ID}/tz-demo-app.git"
        GIT_BRANCH = "devops"                   =>
        GIT_COMMITTER_EMAIL = "rltjdgus@gmail.com"   =>

        DOMAIN = "okestro.me"                   =>
        CLUSTER_NAME = "okestro-k8s"

