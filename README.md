# fxa-self-hosting
Instructions for hosting Mozilla Services on your own domain name. Services included so far:

* General:
  * a simple nginx-based proxy
  * instructions for home-hosting using pagekite
  * instructions for configuring Firefox Desktop to use your self-hosted services
  * instructions for configuring Firefox OS to use your self-hosted services

* Firefox Accounts, including:
  * fxa-content-server
  * fxa-profile-server
  * fxa-auth-server
  * fxa-oauth-server
  * browserid-verifier
  * fxa-auth-db-mysql

* Firefox Sync, including:
  * syncserver (this includes tokenserver)
  * syncto (only required for Firefox OS)


## Work in progress

Do *not* use this in production! It's not ready yet. :) Most services still use
the development settings (see
https://github.com/michielbdejong/fxa-self-hosting/issues/10), so that's entirely
insecure.

## Audience

This guide is intended for people with basic sysadmin experience. If you're having
any trouble, you can ask for help by mentioning me (michielbdejong) in the #fxa channel
on irc.mozilla.org, or email me (michiel at mozilla dot com).

## Prerequisites

For self-hosting (i.e. hosting an instance the Mozilla Services yourself, on a
server that's connected to the internet), you will need:

* A server with probably 1 or 2 Gigs of memory and Docker installed, and that's
not doing anything yet that occupies port 443 (i.e. not hosting any websites)
* A domain name or subdomain you control and can point to this server
* A TLS certificate for this (sub-)domain. Once you have your server running and
your (sub-)domainname pointed to it in DNS (wait for DNS propagation), you can
get one for free from [LetsEncrypt](https://letsencrypt.org/).

If you prefer to host the services on a computer in your house ("home-hosting"),
then you need to make this computer addressable on the public internet. You can
do this using a reverse proxy tunnel like Pagekite (see instructions below), or
maybe with DynDNS. The reverse proxy tunnel needs to run on an addressable server,
but it can be a much smaller (cheaper) one, and also, this reverse proxy tunnel
will not store any of your data (the data would be in your house), and if configured
correctly, it cannot eavesdrop on any of the traffic that goes through it (because
TLS is terminated in your house, not at the proxy).

## Setup

In these instructions, I use fxa.michielbdejong.com as the example subdomain on which
all the services will be running (using various TCP ports). Replace this string with your
own (sub-)domain name wherever you see it. Note that one of the services (fxa-auth-server)
will be occupying port 443 (https://fxa.michielbdejong.com/), so if you already run your
website or blog on your server, you will want to use an extra server, on a subdomain
(I used fxa. in this case).

### Step 1: Getting the TLS certificate

If you get your TLS certificate using LetsEncrypt, it will be saved to /etc/letsencrypt.
Find your certificate there, and copy it to a convenient location on the server that will
be running the services. Note that it's necessary to append chain.pem to cert.pem, so that
the nginx proxy will present a convincing trust chain to https clients. In this case, I'm
saving the cert in a newly created folder, /root/fxa-cert. If you used the certonly method,
/etc/letsencrypt/live may not exist, but you can probably still find the .pem files in some
folder under /etc/letsencrypt if the registration was successful:

````bash
cd /root
cp -r /etc/letsencrypt/live/fxa.michielbdejong.com ./fxa-cert
chmod -R ugo+r ./fxa-cert
cat ./fxa-cert/cert.pem ./fxa-cert/chain.pem > ./fxa-cert/combined.pem
````

### Step 2 (home-hosting only): Set up your pagekite frontend

Replace 'secretsecretsecret' with the secret from your ~/.pagekite.rc file in the
following command, and run it on the pagekite frontend (the server to which DNS
for fxa.michielbdejong.com points):

````bash
pagekite.py --isfrontend --domain *:fxa.michielbdejong.com:secretsecretsecret --ports=80,1111,3030,5000,8000,443,9010
echo TODO: not use a http connection (?) to the frontend
````

### Step 3: Run build.sh

The `build.sh` script from this repo will build the necessary Docker images. This
will probably take up to half an hour, so grab a coffee. You should run this script
regularly, for instance when a new patch version of node 0.10 becomes available.

### Step 4: Run setup.sh

Running `setup.sh fxa.michielbdejong.com` (script in the root of this repo) will
stop and destroy all running Docker containers, so don't run it on a server
where you're also running some other Docker-based things. Make sure to run it with
your own sub-domain instead of 'fxa.michielbdejong.com', of course. You may also
want to convert this bash script to a docker-compose.yml file if that's your
thing; the result will be the same.

The script assumes that `./fxa-cert/combined.pem` and `./fxa-cert/privkey.pem` exist.

Check if you see nine Docker containers running in `docker ps -a` and none of them
exited. It can take a further 10 or 20 seconds before the fxa-content-server will
start responding (you will see a 502 Bad Gateway page from the nginx proxy until then).

### Step 5 (home-hosting only): Set up your pagekite backend

On MacOS, Docker runs inside a virtual machine, probably on 192.168.99.100. In
any case, you can use your browser or a http tool like curl to test if https://192.168.99.100
is responding.

Run `fly.sh fxa.michielbdejong.com` from this repo, and maybe restart the pagekite
frontend and backend (killing all pagekite processes from `ps auxwww | grep pagekite`
in between) until there are no rejected duplicates and https://fxa.michielbdejong.com
looks the same as https://192.186.99.100 (or whatever your Docker VM IP), and same for
the https services on ports :1111, :3030, :5000, :8000, and :9010.

### Step 6: Configuring syncserver

Looking for a proper way to do this through env vars; until then:

````bash
docker exec -it -u root sync /bin/bash
root@b5c1ba63de07:/home/app/syncserver# apt-get update && apt-get install -yq vim
root@b5c1ba63de07:/home/app/syncserver# vim ./local/lib/python2.7/site-packages/tokenserver/verifiers.py +85
-> edit verifier_url = "http://verifier.local:5050/v2"
root@b5c1ba63de07:/home/app/syncserver# exit
````

and restart the sync and proxy containers (in that order, since the proxy container
links to the sync container):

````bash
docker restart sync ; docker restart proxy
````

### Step 7: Creating your account

Sign up on https://fxa.michielbdejong.com:3030/, and instead of going to look
for the verification email, run:

````bash
docker exec -it httpdb mysql -e "USE fxa; UPDATE accounts SET emailVerified=1;"
````

to mark your email address as verified.

NB: If you get https://fxa.michielbdejong.com:3030/unexpected_error, run
localStorage.clear() in the console and hard-refresh.

### Step 8: Configure Firefox Desktop

Edit the values in about:config like so:

![Image about:config](https://cloud.githubusercontent.com/assets/408412/12393881/d144dd5a-bdf8-11e5-8cb6-fb0d233b1d99.png)

### Step 9: (Firefox OS only) Configure and build Gaia

In build/config/common-settings.json, edit:

* "identity.fxaccounts.reset-password.url": "https://fxa.michielbdejong.com:3030/reset_password",
* "sync.fxa.audience": "https://fxa.michielbdejong.com:5000/",
* "sync.server.url": "https://fxa.michielbdejong.com:8000/v1/",

And in build/config/phone/custom-prefs.js (assuming you're building for the phone), add:

* user_pref("identity.fxaccounts.auth.uri", "https://fxa.michielbdejong.com/v1");


There are also two prefs you need to change at the B2G level, but if you're using B2G-Desktop,
you can change it in the /Applications/B2GDebug.app/Contents/Resources/defaults/pref/b2g.js
file without having to rebuild all of B2G. The prefs to change are:

* pref("identity.fxaccounts.remote.oauth.uri", "https://fxa.michielbdejong.com:9010/v1");
* pref("identity.fxaccounts.remote.profile.uri", "https://fxa.michielbdejong.com:1111/v1");

## Debugging

If DNS hasn't propagated yet, you may need to spike /etc/hosts in the profile and
verifier.local containers:

````bash
docker exec -u root -it verifier.local /bin/bash
docker exec -u root -it profile /bin/bash
-> echo 45.32.232.152 fxa.michielbdejong.com >> /etc/hosts
````

... or just wait for a bit. :)

To debug one of the containers, e.g. the one with container id ea298056cc in `docker ps`:

````bash
 docker exec -u root -it ea298056cc /bin/bash
 # add some console.log statements to the code
 docker restart ea298056cc
 docker restart proxy #and/or whichever containers link to the container you edited
 docker logs -f ea298056cc
````

You can also run a container interactively, check setup.sh for the startup params for each one.

Again, you will have to restart containers that link to the restarted one, for instance
the main fxa-self-hosting proxy.

A nice tool for seeing the contents of your sync server is
[syncclient](https://github.com/mozilla-services/syncclient). Apart from following
syncclient's readme instructions, make sure to edit `syncclient/client.py` like this:

````diff
-TOKENSERVER_URL = "https://token.services.mozilla.com/"
-FXA_SERVER_URL = "https://api.accounts.firefox.com"
+TOKENSERVER_URL = "https://fxa.michielbdejong.com:5000/token/"
+FXA_SERVER_URL = "https://fxa.michielbdejong.com"
````

And then try running commands like
`get_collection_counts`, `get_records history`, or  `get_record crypto keys` with it.

# Disclaimer

Don't try this at home. This is a work-in-progress, hasn't been security-reviewed yet, and it's
just not secure enough to host your valuable Firefox Sync data.
