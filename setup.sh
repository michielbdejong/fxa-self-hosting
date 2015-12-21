#!/bin/bash
echo This startup script is for Ubuntu Wily 15.10

echo General setup

apt-get update -y
apt-get upgrade -y
apt-get install -y unattended-upgrades git vim python


echo Setting up Docker

apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo deb https://apt.dockerproject.org/repo ubuntu-wily main > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get purge lxc-docker*
apt-get install -y linux-image-extra-$(uname -r) docker-engine docker-compose
service docker start

echo Building Mozilla images

docker build -t fxa-letsencrypt https://github.com/michielbdejong/fxa-letsencrypt.git#docker
docker build -t fxa-content-server https://github.com/michielbdejong/fxa-content-server.git#docker

echo Setting up LetsEncrypt

docker run -it --net=host --rm -v /etc/letsencrypt:/etc/letsencrypt fxa-letsencrypt /bin/bash -c "service apache2 start && ./letsencrypt-auto --apache"

echo Starting up
git clone https://github.com/michielbdejong/fxa-self-hosting
cd fxa-self-hosting
docker-compose up
