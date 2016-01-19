#!/bin/bash

echo Building Mozilla images

docker build -f ./docs/self-host.docker -t fxa-content-server https://github.com/michielbdejong/fxa-content-server.git#docker
docker build -f ./docs/self-host.docker -t fxa-auth-server https://github.com/michielbdejong/fxa-auth-server.git#docker
docker build -f ./docs/self-host.docker -t fxa-auth-db-mysql https://github.com/michielbdejong/fxa-auth-db-mysql.git#docker
docker build -f ./docs/self-host.docker -t fxa-oauth-server https://github.com/michielbdejong/fxa-oauth-server.git#docker
docker build -f ./docs/self-host.docker -t browserid-verifier https://github.com/michielbdejong/browserid-verifier.git#docker
docker build -f ./docs/self-host.docker -t fxa-profile-server https://github.com/michielbdejong/fxa-profile-server.git#docker
docker build -t syncserver https://github.com/mozilla-services/syncserver.git
docker build -t syncto https://github.com/michielbdejong/syncto.git#docker
docker build -t fxa-self-hosting https://github.com/michielbdejong/fxa-self-hosting.git
