# Replicator Example

## Standalone Replicator
This example covers a setup of 2 CP clusters with a Replicator-based replication using a standlone Replicator in the destination cluster.
Official Docs: 

## Connect-based Replicator
This example covers a setup of 2 CP clusters with a Replicator-based replication using a Connect-based replicator in the destination cluster.

## General Setup
The cluster setup is the same as the example in [cluster-link](../cluster-link) with an additional Connect node in the destination environment for running Replicator. See the [Replicator Documentation](https://docs.confluent.io/platform/current/multi-dc-deployments/replicator/configuration_options.html) for description of all configuration options.

Execute `./setup.sh` and wait for CP to be up and running and topic to be created.

* Produce random data:
```shell
kubectl exec kcat -it -- bash -c "date | \
  kcat -b kafka.source:9092 -t test-topic -P"

cat <<EOF >/tmp/record
{ "FirstName": "Fred", "Surname": "Smith", "Age": 28 }
EOF
```
## Replicator Setup and testing

### Connect-based Replicator
Replicator is deployed using Kafka Connect. Steps:
* Deploy connector CR according to use-case:
```shell
# pull-scenario (default)
kubectl apply -f ./connect.yaml -n source
kubectl apply -f ./replicator-dest-byte.yaml
# OR push-scenario:
kubectl apply -f ./connect.yaml -n destination
kubectl apply -f ./replicator-src-byte.yaml
```

* Connector example configurations:
Pull-scenario (default, Replicator in destination cluster):
```json
{
  "name": "replicator-pull",
  "connector.class": "io.confluent.connect.replicator.ReplicatorSourceConnector",
  "header.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
  "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
  "src.kafka.bootstrap.servers": "kafka.source.svc.cluster.local:9092",
  "tasks.max": "1",
  "topic.auto.create": "false",
  "topic.regex": "^test-.*",
  "topic.rename.format": "${topic}.replicated",
  "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter"
}
```

Push-scenario (Replicator in source cluster) needs producer-override:
```json
{
  "name": "replicator-push",
  "connector.class": "io.confluent.connect.replicator.ReplicatorSourceConnector",
  "confluent.topic.bootstrap.servers": "kafka.source.svc.cluster.local:9092",
  "dest.kafka.bootstrap.servers": "kafka.destination.svc.cluster.local:9092",
  "header.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
  "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
  "producer.override.bootstrap.servers": "kafka.destination.svc.cluster.local:9092",
  "src.kafka.bootstrap.servers": "kafka.source.svc.cluster.local:9092",
  "tasks.max": "1",
  "topic.auto.create": "false",
  "topic.regex": "^test-.*",
  "topic.rename.format": "${topic}.replicated",
  "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter"
}
```

### Standalone Replicator
* Deploy CR according to use-case:
```shell
kubectl apply -f ./replicator-standalone-src.yaml -n source
# OR:
kubectl apply -f ./replicator-standalone-dest.yaml -n destination
```