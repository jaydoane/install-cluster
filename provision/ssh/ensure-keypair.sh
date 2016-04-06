#!/bin/bash -e

file=id_rsa

if [ ! -f $file ]
then
    ssh-keygen -f $file -t rsa -N ''
fi
