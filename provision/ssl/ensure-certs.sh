#!/bin/bash -e

file=id_rsa

if [ ! -f $file ]
then
    ssh-keygen -f $file -t rsa -N ''
fi

openssl genrsa -out privkey.key

        # "openssl req -x509 -nodes -days 3650 "
        # "-subj '/C=US/ST=CA/O=NetCP Inc/CN=netcp.example.com' "
        # "-newkey rsa:2048 -keyout ~s -out ~s", [Keyfile, Certfile]),

cast node config # to regenerate haproxy.cfg
