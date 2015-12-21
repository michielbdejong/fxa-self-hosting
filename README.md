# fxa-self-hosting
Instructions for hosting a Firefox Accounts instance on your own domain name

## Steps:
* Get a domain name if you don't have one yet.
* Get a fresh Ubuntu 15.10 server.
* Point fxa.yourdomain.com to your Ubuntu server in DNS
* Ssh into your server, and run:
````bash
wget https://raw.githubusercontent.com/michielbdejong/fxa-self-hosting/master/setup.sh | sh
````
* Follow the instructions to register a LetsEncrypt certificate, answers:
  * Yes
  * fxa.yourdomain.com
  * your@email.com
  * Agree
  * Secure
  * Ok

* Browse to https://fxa.yourdomain.com/
