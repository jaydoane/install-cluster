#!/bin/bash -ex

platform=${platform-trusty}
installer=cloudant-latest-${platform}-x86_64.bin
installer_url=s3://cloudant-local/builds

s3cmd sync $installer_url/$installer ./
