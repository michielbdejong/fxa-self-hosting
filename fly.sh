#!/bin/bash
die () {
    echo >&2 "$@"
    exit 1
}

[ "$#" -eq 1 ] || die "1 argument required, $# provided"
echo $1 | grep -E -q '^[a-z0-9\.]+$' || die "Argument $1 does not look like a domain name"

echo Running pagekite backend for $1

pagekite.py --frontend=$1:80 \
            192.168.99.100:1111 https://$1:1111 AND \
            192.168.99.100:3030 https://$1:3030 AND \
            192.168.99.100:5000 https://$1:5000 AND \
            192.168.99.100:8000 https://$1:8000 AND \
            192.168.99.100:443 https://$1:443 AND \
            192.168.99.100:9010 https://$1:9010
