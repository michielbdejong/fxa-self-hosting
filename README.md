# fxa-self-hosting
Instructions for hosting a Firefox Accounts instance on your own domain name

## Steps:
* Get a domain name
* Get a server. I use Vultr.com to create an Ubuntu 15.10 instance, and then install Docker using the following script:

````bash
#!/bin/bash

echo This startup script is for Ubuntu Wily 15.10


## General setup

apt-get update
apt-get upgrade
apt-get install -y unattended-upgrades git vim python


## Docker

apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo deb https://apt.dockerproject.org/repo ubuntu-wily main > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get purge lxc-docker*
apt-get install -y linux-image-extra-$(uname -r) docker-engine
service docker start
````

* Point fxa.yourdomain.com to your server in DNS
* Ssh into your server, and run:
````bash
docker build -t fxa-letsencrypt https://github.com/michielbdejong/fxa-letsencrypt.git#docker

docker run -it --net=host --name fxa-letsencrypt fxa-letsencrypt /bin/bash
````
* This will open a bash shell inside the container; in there, run:
````bash
./letsencrypt-auto --apache
````
* Follow the instructions to register a LetsEncrypt certificate, answers:
  * Yes
  * fxa.yourdomain.com
  * your@email.com
  * Agree
  * Secure
  * Ok

* Type `exit` to leave the container, and start it again:
````bash
docker start `docker ps -aq` # TODO: find a nicer way
````
* Browse to https://fxa.mydomain.com/
