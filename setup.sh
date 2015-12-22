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
docker build -t fxa-self-hosting https://github.com/michielbdejong/fxa-self-hosting.git#docker

echo Setting up LetsEncrypt

docker run -it --net=host --rm -v /etc/letsencrypt:/etc/letsencrypt fxa-letsencrypt /bin/bash -c "service apache2 start && ./letsencrypt-auto --apache"
cp -r /etc/letsencrypt/live/fxa.michielbdejong.com /root/fxa-cert
chmod -R ugo+r /root/fxa-cert

echo Starting up


docker run -d \
           -e "HOST=0.0.0.0" \
           --name httpdb fxa-auth-db-mysql

docker run -d \
           --name verifier.local \
           -e "IP_ADDRESS=0.0.0.0" \
           -e "PORT=5050" \
           -e "INSECURE_SSL=true" \
           browserid-verifier


docker run -d \
           -p 3030:3030 \
           -v /root/fxa-cert:/fxa-cert \
           -e "PUBLIC_URL=https://fxa.michielbdejong.com:3030" \
           -e "FXA_URL=https://fxa.michielbdejong.com:9000" \
           -e "FXA_OAUTH_URL=https://fxa.michielbdejong.com:9010" \
           -e "FXA_PROFILE_URL=https://fxa.michielbdejong.com:1111" \
           -e "USE_TLS=true" \
           -e "TLS_KEY_PATH=/fxa-cert/privkey.pem" \
           -e "TLS_CERT_PATH=/fxa-cert/cert.pem" \
           -e "REDIRECT_PORT=3031" \
            fxa-content-server

docker run -d \
           --link="httpdb" \
           -p 9000:9000 \
           -v /root/fxa-cert:/fxa-cert \
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
           -v /root/fxa-cert:/fxa-cert \
           -e "PUBLIC_URL=https://fxa.michielbdejong.com:9010" \
           -e "HOST=0.0.0.0" \
           -e "CONTENT_URL=https://fxa.michielbdejong.com:3030/oauth/" \
           -e "VERIFICATION_URL=http://verifier.local:5050/v2" \
           fxa-oauth-server

 docker run -d \
            --name profile \
            -e "PUBLIC_URL=https://fxa.michielbdejong.com:1111" \
            -e "AUTH_SERVER_URL=https://fxa.michielbdejong.com:9000" \
            -e "OAUTH_SERVER_URL=https://fxa.michielbdejong.com:9010" \
            -e "IMG=local" \
            -e "HOST=0.0.0.0" \
            fxa-profile-server

docker run -d \
           --name sync \
           syncserver

docker run -d \
           --name syncto \
           syncto

docker run -d \
           --link="profile" \
           -p 1111:1111 \
           --link="sync" \
           -p 5000:5000 \
           --link="syncto" \
           -p 8000:8000 \
           -v /root/fxa-cert:/fxa-cert \
           fxa-self-hosting

