curl -X PUT http://localhost:5984/_users -u admin:pass
curl -X PUT http://localhost:5984/_users/org.couchdb.user:member -H "Accept: application/json"  -H "Content-Type: application/json"  -d '{"name": "member", "password": "pass", "type": "user"}'  -u admin:pass

curl -X GET http://localhost:5984/_users/_all_docs -u admin:pass
curl -X GET http://localhost:5984/_users/org.couchdb.user:member -u admin:pass

set -e
for i in {1..100}; do curl -f http://localhost:5984/_session -u member:pass; done
