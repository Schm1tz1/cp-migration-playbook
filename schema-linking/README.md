# Schema Linking
Official Docs: https://docs.confluent.io/operator/current/co-link-schemas.html
This example convers a setup of 2 CP clusters showing the possibilities of a 1:1 schema linking into the default context without any prefixing/context changes.

## General Setup
* Execute `./setup.sh` and wait for CP to be up and running and a schema to be created in the source.

* List schemas:
Use script `./list_subjects.sh`, alternatively:

* List in source (containe example schema):
```shell
$ kubectl exec schemaregistry-0 -n source -it -- bash -c "curl -k http://localhost:8081/subjects"
Defaulted container "schemaregistry" out of: schemaregistry, config-init-container (init)
["payment-value"]
````
* List in destination (should be empty):
```shell
$ kubectl exec schemaregistry-0 -n destination -it -- bash -c "curl -k http://localhost:8081/subjects"
Defaulted container "schemaregistry" out of: schemaregistry, config-init-container (init)
[]
```

## Configure and start exporter using CFK CR
* Start schema link / exporter:
```shell
kubectl apply -f schema-exporter.yaml
```

* Check subjects in destination cluster:
```shell
kubectl exec schemaregistry-0 -n destination -it -- bash -c "curl -k http://localhost:8081/subjects"
```

## Configure and start exporter using CLI
Desired exporter state (describe):
```json
{"name":"schema-exporter","subjects":["*"],"contextType":"NONE","config":{"schema.registry.url":"http://schemaregistry.destination.svc.cluster.local:8081"}}
```

* Create basic configuration:
```shell
kubectl exec schemaregistry-0 -n source -it -- bash -c "echo 'schema.registry.url=http://schemaregistry.destination.svc.cluster.local:8081' >/tmp/exporter.txt"
```

* Create exporter:
```shell
kubectl exec schemaregistry-0 -n source -it -- bash -c "schema-exporter --create --schema.registry.url http://localhost:8081 --name exporter1 --config-file /tmp/exporter.txt --context-type NONE"
```

* Double-check state (in SR container):
```shell
bash-4.4$ schema-exporter --describe --schema.registry.url http://localhost:8081 --name exporter1
{"name":"exporter1","subjects":["*"],"contextType":"NONE","context":".","config":{"schema.registry.url":"http://schemaregistry.destination.svc.cluster.local:8081"}}
```

* Wait and check state (in SR container):
```shell
bash-4.4$ schema-exporter --get-status --schema.registry.url http://localhost:8081 --name exporter1
{"name":"exporter1","state":"RUNNING","offset":2,"ts":1742374525127,"deksOffset":-1,"deksTs":0}
```

* Pause and delete exporter (in SR container):
```shell
bash-4.4$ schema-exporter --pause --schema.registry.url http://localhost:8081 --name exporter1
Successfully paused exporter exporter1
bash-4.4$ schema-exporter --delete --schema.registry.url http://localhost:8081 --name exporter1
Successfully deleted exporter exporter1
```
