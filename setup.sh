#!/bin/bash

docker build -t fxa-letsencrypt https://github.com/michielbdejong/fxa-letsencrypt.git#docker
docker build -t fxa-content-server https://github.com/michielbdejong/fxa-content-server.git#docker

docker run -it --net=host --rm -v /etc/letsencrypt:/etc/letsencrypt fxa-letsencrypt /bin/bash -c "service apache2 start && ./letsencrypt-auto --apache"

docker-compose up
