# MirrorMaker2 Example

## Standalone MM2
This example covers a setup of 2 CP clusters with a MM2-based replication using a Standlone MM2 in the destination cluster.
Official Docs: https://kafka.apache.org/documentation/#mirrormakerconfigs
Important KIPs on MM2:
* https://cwiki.apache.org/confluence/display/KAFKA/KIP-382%3A+MirrorMaker+2.0
* https://cwiki.apache.org/confluence/display/KAFKA/KIP-618%3A+Exactly-Once+Support+for+Source+Connectors
* https://cwiki.apache.org/confluence/display/KAFKA/KIP-710%3A+Full+support+for+distributed+mode+in+dedicated+MirrorMaker+2.0+clusters

## Connect-based MM2
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

### Connect-based MM2
MM2 is deployed using Kafka Connect. Steps:
* Deploy connector CR according to use-case:
```shell
kubectl apply -f ./connect.yaml -n source
kubectl apply -f ./mm2-src.yaml
# OR:
kubectl apply -f ./connect.yaml -n destination
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

### Standalone MM2
* Deploy connector CR according to use-case:
```shell
kubectl apply -f ./mm2-standalone-cfg.yaml -n source
kubectl apply -f ./mm2-standalone-secret.yaml -n source
kubectl apply -f ./mm2-standalone.yaml -n source
# OR:
kubectl apply -f ./mm2-standalone-cfg.yaml -n destination
kubectl apply -f ./mm2-standalone-secret.yaml -n destination
kubectl apply -f ./mm2-standalone.yaml -n destination
```

### Adding Monitoring Agents
By default, a simple prometheus JMX exporter is added. Make sure that the file `/mnt/config/jmx-exporter.yaml` is mounted correctly from the ConfigMap and also check that the agent JAR exists and has the correct version in the MM2 deployment `EXTRA_ARGS` (e.g. `/usr/share/java/cp-base-new/jmx_prometheus_javaagent-0.18.0.jar` for CP 7.8.1). 
