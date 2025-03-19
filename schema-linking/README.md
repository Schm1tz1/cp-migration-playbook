# Schema Linking
Official Docs: https://docs.confluent.io/operator/current/co-link-schemas.html
This example convers a setup of 2 CP clusters showing the possibilities of a topic mirroring/migration.

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

* Check topics in destination cluster:
```shell
kubectl exec kafka-0 -n destination -it \
  -- kafka-topics --bootstrap-server localhost:9092 --list
kubectl get kafkatopics -A -o wide
```

## Configure and start exporter using CLI
