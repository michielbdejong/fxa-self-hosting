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
docker build -t fxa-auth-server https://github.com/michielbdejong/fxa-auth-server.git#docker
docker build -t fxa-auth-db-mysql https://github.com/michielbdejong/fxa-auth-db-mysql.git#docker
docker build -t fxa-oauth-server https://github.com/michielbdejong/fxa-oauth-server.git#docker
docker build -t browserid-verifier https://github.com/michielbdejong/browserid-verifier.git#docker
docker build -t fxa-profile-server https://github.com/michielbdejong/fxa-profile-server.git#docker
docker build -t syncserver https://github.com/michielbdejong/syncserver.git#docker
docker build -t syncto https://github.com/michielbdejong/syncto.git#docker
docker build -t fxa-self-hosting https://github.com/michielbdejong/fxa-self-hosting.git

echo Setting up LetsEncrypt

docker run -it --net=host --rm -v `pwd`/letsencrypt:/etc/letsencrypt fxa-letsencrypt /bin/bash

$ service apache2 start
-> check http://fxa.michielbdejong.com and https://fxa.michielbdejong.com (cert warning) show the apache default page
$ ./letsencrypt-auto --apache --text -vv
-> answer the questions: Yes, fxa.michielbdejong.com, michiel@mozilla.com, Agree
$ exit

cp -r `pwd`/letsencrypt/live/fxa.michielbdejong.com `pwd`/fxa-cert
chmod -R ugo+r `pwd`/fxa-cert

echo Stopping all running Docker containers
docker stop `docker ps -q`
docker rm `docker ps -aq`

echo Starting up

cd ~/notes

docker rm httpdb
docker run -d \
           -e "HOST=0.0.0.0" \
           --name httpdb \
          fxa-auth-db-mysql

docker rm verifier.local
docker run -d \
           --name verifier.local \
           -e "IP_ADDRESS=0.0.0.0" \
           -e "PORT=5050" \
           browserid-verifier

docker rm profile
docker run -d \
           --name profile \
           -e "PUBLIC_URL=https://fxa.michielbdejong.com:1111" \
           -e "AUTH_SERVER_URL=https://fxa.michielbdejong.com:9000" \
           -e "OAUTH_SERVER_URL=https://fxa.michielbdejong.com:9010" \
           -e "IMG=local" \
           -e "HOST=0.0.0.0" \
           fxa-profile-server

docker rm sync
docker run -d \
           --name sync \
           syncserver

docker rm syncto
docker run -d \
           --name syncto \
           syncto

docker run -d \
           -p 3030:3030 \
           -v `pwd`/fxa-cert:/fxa-cert \
           -e "PUBLIC_URL=https://fxa.michielbdejong.com" \
           -e "FXA_URL=https://fxa.michielbdejong.com:9000" \
           -e "FXA_OAUTH_URL=https://fxa.michielbdejong.com:9010" \
           -e "FXA_PROFILE_URL=https://fxa.michielbdejong.com:1111" \
           -e "USE_TLS=true" \
           -e "TLS_KEY_PATH=/fxa-cert/privkey.pem" \
           -e "TLS_CERT_PATH=/fxa-cert/cert.pem" \
           -e "TLS_CA_PATH=/fxa-cert/chain.pem" \
           -e "REDIRECT_PORT=3031" \
            fxa-content-server

echo Sleeping to let services come up before linking
sleep 5

docker run -d \
           --link="httpdb" \
           -p 9000:9000 \
           -v `pwd`/fxa-cert:/fxa-cert \
           -e "IP_ADDRESS=0.0.0.0" \
           -e "PUBLIC_URL=https://fxa.michielbdejong.com:9000" \
           -e "HTTPDB_URL=http://httpdb:8000" \
           -e "USE_TLS=true" \
           -e "TLS_KEY_PATH=/fxa-cert/privkey.pem" \
           -e "TLS_CERT_PATH=/fxa-cert/cert.pem" \
           fxa-auth-server

docker run -d \
           --link="verifier.local" \
           -p 9010:9010 \
           -v `pwd`/fxa-cert:/fxa-cert \
           -e "PUBLIC_URL=https://fxa.michielbdejong.com:9010" \
           -e "HOST=0.0.0.0" \
           -e "CONTENT_URL=https://fxa.michielbdejong.com/oauth/" \
           -e "VERIFICATION_URL=http://verifier.local:5050/v2" \
           fxa-oauth-server

# Proxy for three servers that can't run https themselves:
docker run -d \
           --link="profile" \
           -p 1111:1111 \
           --link="sync" \
           -p 5000:5000 \
           --link="syncto" \
           -p 8000:8000 \
           -v `pwd`/fxa-cert:/fxa-cert \
           fxa-self-hosting

docker ps -a
# You should see 9 servers
# - fxa-self-hosting,
# - fxa-oauth-server,
# - fxa-auth-server,
# - fxa-content-server,
# - syncto,
# - syncserver,
# - fxa-profile-server,
# - browserid-verifier,
# - fxa-auth-db-mysql
#
echo On Mac, see https://[$DOCKER_HOST]:3030/


# Running pagekite:

## Backend:
pagekite.py --frontend=fxa.michielbdejong.com:80 \
            192.168.99.100:3030 https://fxa.michielbdejong.com:3030 AND \
            192.168.99.100:9000 https://fxa.michielbdejong.com:9000 AND \
            192.168.99.100:9010 https://fxa.michielbdejong.com:9010 AND \
            192.168.99.100:1111 https://fxa.michielbdejong.com:1111 AND \
            192.168.99.100:5000 https://fxa.michielbdejong.com:5000 AND \
            192.168.99.100:8000 https://fxa.michielbdejong.com:8000

## Frontend:
pagekite.py --isfrontend --domain *:fxa.michielbdejong.com:secretsecretsecret --ports=80,3030,9000,9010,1111,5000,8000
## TODO: not use a http connection to the frontend
