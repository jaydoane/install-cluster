#!/bin/bash -e

until $(curl --output /dev/null --silent --head --fail http://localhost:5984); do
    printf '.'
    sleep 1
done

curl -X PUT http://localhost:5984/_users/org.couchdb.user:user2 -H "Accept: application/json" -H "Content-Type: application/json" -d '{"name": "user2", "password": "pass", "type": "user"}' -u {{ admins[0].name }}:{{ admins[0].pass }}
