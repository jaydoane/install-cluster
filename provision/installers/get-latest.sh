#!/bin/bash -ex

PLATFORM=${PLATFORM-trusty}

installer_re=cloudant-[0-9.-]+${PLATFORM}-x86_64.tar.gz
installer_url=s3://cloudant-local-installer/releases/latest

installer=`s3cmd ls $installer_url/ | egrep -o $installer_re`
s3cmd get $installer_url/$installer --skip-existing
