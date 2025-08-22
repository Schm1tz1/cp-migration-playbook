# Replicator Example

## Standalone Replicator
This example covers a setup of 2 CP clusters with a MM2-based replication using a Standlone Replicator in the destination cluster.
Official Docs: 

## Connect-based Replicator
TODO

## General Setup
The cluster setup is the same as the example in [cluster-link](../cluster-link) with an additional Connect node in the destination environment for running Replicator.
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
kubectl apply -f ./replicator-src.yaml
# OR:
kubectl apply -f ./connect.yaml -n destination
kubectl apply -f ./replicator-dest.yaml
```

* Connector example configurations:
Pull-scenario (default, Replicator in destination cluster):
```json
{
  ...
}
```

Push-scenario (Replicator in source cluster) needs producer-override:
```json
{
  ...
}
```

### Standalone Replicator
* Deploy CR according to use-case:
```shell
kubectl apply -f ./replicator-standalone-src.yaml -n source
# OR:
kubectl apply -f ./replicator-standalone-dest.yaml -n destination
```