# MirrorMaker2 Example
This example covers a setup of 2 CP clusters with a MM2-based replication using a Connect-based MM2 in the destination cluster.
Official Docs: https://kafka.apache.org/documentation/#mirrormakerconfigs
Important KIPs on MM2:
* https://cwiki.apache.org/confluence/display/KAFKA/KIP-382%3A+MirrorMaker+2.0
* https://cwiki.apache.org/confluence/display/KAFKA/KIP-618%3A+Exactly-Once+Support+for+Source+Connectors
* https://cwiki.apache.org/confluence/display/KAFKA/KIP-710%3A+Full+support+for+distributed+mode+in+dedicated+MirrorMaker+2.0+clusters

## General Setup
The cluster setup is the same as the example in [cluster-link](../cluster-link) with an additional Connect node in the destination environment for running MM2.
Execute `./setup.sh` and wait for CP to be up and running and topic to be created.

* Produce random data:
```shell
kubectl exec kcat -it -- bash -c "date | \
  kcat -b kafka.source:9092 -t test-topic -P"
```
## MM2 Setup and testing
MM2 is deployed unsing Kafka Connect. Steps:
* Deploy connector CR according to use-case:
```shell
kubectl apply -f ./mm2-src.yaml
# OR:
kubectl apply -f ./mm2-dest.yaml
```
Note: Default naming of the destination topic is by prefixing with the source cluster alias, e.g. `test-topic` will be mirrored to `SRC.test-topic` by default. By using `replication.policy.class=org.apache.kafka.connect.mirror.IdentityReplicationPolicy` (available since AK 3.0), topic names will be mirrored 1:1. This is added to the CR configs in this example by default.

* Connector example configurations:
Pull-scenario (default, MM2 in destination cluster):
```json
{
  "connector.class": "org.apache.kafka.connect.mirror.MirrorSourceConnector",
  "name":"test_mirror",
  "source.cluster.alias":"OLD",
  "target.cluster.alias":"NEW",
  "topics":"test-topic",
  "source.cluster.bootstrap.servers":"kafka.source.svc.cluster.local:9092",
  "target.cluster.bootstrap.servers":"kafka.destination.svc.cluster.local:9092",
  "key.converter":"org.apache.kafka.connect.converters.ByteArrayConverter",
  "value.converter":"org.apache.kafka.connect.converters.ByteArrayConverter"
}
```

Push-scenario (MM2 in source cluster) needs producer-override:
```json
{
  "connector.class": "org.apache.kafka.connect.mirror.MirrorSourceConnector",
  "name":"test_mirror",
  "source.cluster.alias":"OLD",
  "target.cluster.alias":"NEW",
  "topics":"test-topic",
  "source.cluster.bootstrap.servers":"kafka.source.svc.cluster.local:9092",
  "target.cluster.bootstrap.servers":"kafka.destination.svc.cluster.local:9092",
  "producer.override.bootstrap.servers":"kafka.destination.svc.cluster.local:9092",
  "key.converter":"org.apache.kafka.connect.converters.ByteArrayConverter",
  "value.converter":"org.apache.kafka.connect.converters.ByteArrayConverter"
}
```

