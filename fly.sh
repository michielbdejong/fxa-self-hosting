echo Running pagekite backend

pagekite.py --frontend=fxa.michielbdejong.com:80 \
            192.168.99.100:1111 https://fxa.michielbdejong.com:1111 AND \
            192.168.99.100:3030 https://fxa.michielbdejong.com:3030 AND \
            192.168.99.100:5000 https://fxa.michielbdejong.com:5000 AND \
            192.168.99.100:8000 https://fxa.michielbdejong.com:8000 AND \
            192.168.99.100:443 https://fxa.michielbdejong.com:443 AND \
            192.168.99.100:9010 https://fxa.michielbdejong.com:9010
