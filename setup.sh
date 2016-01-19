#!/bin/bash
die () {
    echo >&2 "$@"
    exit 1
}

[ "$#" -eq 1 ] || die "1 argument required, $# provided"
echo $1 | grep -E -q '^[a-z0-9\.]+$' || die "Argument $1 does not look like a domain name"
[ -f "./fxa-cert/combined.pem" ] || die "./fxa-cert/combined.pem does not exist"
[ -f "./fxa-cert/privkey.pem" ] || die "./fxa-cert/privkey.pem does not exist"

echo Creating syncserver-config
mkdir -p syncserver-config
cat <<EOF > syncserver-config/syncserver.ini
[server:main]
use = egg:gunicorn
host = 0.0.0.0
port = 5000
workers = 1
timeout = 30

[app:main]
use = egg:syncserver

[syncserver]
force_wsgi_environ = true
public_url = https://$1:5000/
audiences = https://$1:5000
EOF

echo Stopping all running Docker containers
docker stop `docker ps -q`
docker rm `docker ps -aq`

echo Starting up services for $1

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
           -e "PUBLIC_URL=https://$1:1111" \
           -e "AUTH_SERVER_URL=https://$1/v1" \
           -e "OAUTH_SERVER_URL=https://$1:9010/v1" \
           -e "IMG=local" \
           -e "HOST=0.0.0.0" \
           fxa-profile-server

docker run -d \
           --name syncto \
           -e "SYNCTO_TOKEN_SERVER_URL=https://$1:5000/token/" \
           syncto

docker run -d \
           --name content \
           -e "PUBLIC_URL=https://$1:3030" \
           -e "FXA_URL=https://$1" \
           -e "FXA_OAUTH_URL=https://$1:9010" \
           -e "FXA_PROFILE_URL=https://$1:1111" \
           -e "REDIRECT_PORT=3031" \
           fxa-content-server

echo Sleeping to let services come up before linking
sleep 5

docker run -d \
           --name sync \
           --link="verifier.local" \
           -v `pwd`/syncserver-config:/config:ro \
           --entrypoint ./local/bin/gunicorn \
           syncserver \
           --paste /config/syncserver.ini

docker run -d \
           --name auth \
           --link="httpdb" \
           -e "IP_ADDRESS=0.0.0.0" \
           -e "PUBLIC_URL=https://$1" \
           -e "HTTPDB_URL=http://httpdb:8000" \
           -e "OAUTH_URL=https://$1:9010" \
           fxa-auth-server

docker run -d \
           --link="verifier.local" \
           --name oauth \
           -e "PUBLIC_URL=https://$1:9010" \
           -e "HOST=0.0.0.0" \
           -e "CONTENT_URL=https://$1:3030/oauth/" \
           -e "VERIFICATION_URL=http://verifier.local:5050/v2" \
           -e "ISSUER=$1" \
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
