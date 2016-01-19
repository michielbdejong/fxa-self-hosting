#!/bin/bash

echo Stopping all running Docker containers
docker stop `docker ps -q`
docker rm `docker ps -aq`

echo Starting up

cd ~/notes

docker run -d \
           -e "HOST=0.0.0.0" \
           --name httpdb \
          fxa-auth-db-mysql

docker run -d \
           --name verifier.local \
           -e "IP_ADDRESS=0.0.0.0" \
           -e "PORT=5050" \
           browserid-verifier \
           npm start

docker run -d \
           --name profile \
           -e "PUBLIC_URL=https://fxa.michielbdejong.com:1111" \
           -e "AUTH_SERVER_URL=https://fxa.michielbdejong.com/v1" \
           -e "OAUTH_SERVER_URL=https://fxa.michielbdejong.com:9010/v1" \
           -e "IMG=local" \
           -e "HOST=0.0.0.0" \
           fxa-profile-server

docker run -d \
           --name syncto \
           -e "SYNCTO_TOKEN_SERVER_URL=https://fxa.michielbdejong.com:5000/token/" \
           syncto

docker run -d \
           --name content \
           -e "PUBLIC_URL=https://fxa.michielbdejong.com:3030" \
           -e "FXA_URL=https://fxa.michielbdejong.com" \
           -e "FXA_OAUTH_URL=https://fxa.michielbdejong.com:9010" \
           -e "FXA_PROFILE_URL=https://fxa.michielbdejong.com:1111" \
           -e "REDIRECT_PORT=3031" \
           fxa-content-server

echo Sleeping to let services come up before linking
sleep 5

docker run -d \
           --name sync \
           --link="verifier.local" \
           syncserver

docker run -d \
           --name auth \
           --link="httpdb" \
           -e "IP_ADDRESS=0.0.0.0" \
           -e "PUBLIC_URL=https://fxa.michielbdejong.com" \
           -e "HTTPDB_URL=http://httpdb:8000" \
           -e "OAUTH_URL=https://fxa.michielbdejong.com:9010" \
           fxa-auth-server

docker run -d \
           --link="verifier.local" \
           --name oauth \
           -e "PUBLIC_URL=https://fxa.michielbdejong.com:9010" \
           -e "HOST=0.0.0.0" \
           -e "CONTENT_URL=https://fxa.michielbdejong.com:3030/oauth/" \
           -e "VERIFICATION_URL=http://verifier.local:5050/v2" \
           -e "ISSUER=fxa.michielbdejong.com" \
           fxa-oauth-server

echo Sleeping to let services come up before linking
sleep 5

echo Setting up proxy

docker run -d \
           --name proxy \
           --link="profile" \
           -p 1111:1111 \
           --link="content" \
           -p 3030:3030 \
           --link="sync" \
           -p 5000:5000 \
           --link="syncto" \
           -p 8000:8000 \
           --link="auth" \
           -p 443:9000 \
           --link="oauth" \
           -p 9010:9010 \
           -v `pwd`/fxa-cert:/fxa-cert \
           fxa-self-hosting

docker ps -a
echo You should see 9 servers
echo - fxa-self-hosting,
echo - fxa-oauth-server,
echo - fxa-auth-server,
echo - fxa-content-server,
echo - syncto,
echo - syncserver,
echo - fxa-profile-server,
echo - browserid-verifier,
echo - fxa-auth-db-mysql
