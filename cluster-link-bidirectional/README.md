# Cluster Linking
Official Docs: https://docs.confluent.io/operator/current/co-link-clusters.html
This example covers a setup of 2 CP clusters with an active/passive bidirectional cluster link. We will use the link to mirror a topic from a source to the destination cluster, then start using the destination with our clients and afterwards reverse the link using the *reverse* feature (https://docs.confluent.io/cloud/current/multi-cloud/cluster-linking/mirror-topics-cc.html#reverse-source-and-mirror-topic).



## General Setup
The cluster setup is the same as the example in [cluster-link](../cluster-link).
Execute `./setup.sh` and wait for CP to be up and running and topic to be created.
(Note: A bidirectional link required Confluent Enterprise in BOTH clusters.)

* Produce random data:
```shell
kubectl exec kcat -it -- bash -c "date | \
  kcat -b kafka.source:9092 -t test-topic -P"
```
## ClusterLink Setup using ClusterLink-CR
This feature is currently not supported (see https://docs.confluent.io/operator/current/co-link-clusters.html#requirements-and-considerations).

## ClusterLink Setup using ClusterLink-CLI
For a bidirectional clsuter link, we need to activate the link on both sides. For more details also see https://docs.confluent.io/cloud/current/multi-cloud/cluster-linking/cluster-links-cc.html#bidirectional-mode. Steps:

* Create bidirectional Cluster Link and mirror topics:
```shell
kubectl exec kafka-0 -n source -it \
  -- kafka-cluster-links --bootstrap-server localhost:9092 --create --link two-way-link --config bootstrap.servers=kafka.destination.svc.cluster.local:9092,link.mode=BIDIRECTIONAL
kubectl exec kafka-0 -n destination -it \
  -- kafka-cluster-links --bootstrap-server localhost:9092 --create --link two-way-link --config bootstrap.servers=kafka.source.svc.cluster.local:9092,link.mode=BIDIRECTIONAL

kubectl exec kafka-0 -n destination -it \
  -- kafka-mirrors --create --mirror-topic test-topic --link two-way-link --bootstrap-server localhost:9092
```
* List and check topics in destination cluster:
```shell
kubectl exec kafka-0 -n destination -it \
  -- kafka-topics --bootstrap-server localhost:9092 --list
kubectl exec kafka-0 -n destination -it \
  -- kafka-topics --bootstrap-server localhost:9092 --describe --topic test-topic
```
* Check mirror topic status:
```shell
kubectl exec kafka-0 -n destination -it \
  -- kafka-replica-status --topics test-topic --include-mirror --bootstrap-server localhost:9092 
```

```shell
$ kubectl exec kafka-0 -n destination -it -- kafka-mirrors --bootstrap-server localhost:9092 --describe --links two-way-link
Topic: test-topic       LinkName: two-way-link  LinkId: 5gwqidUzSrebDjx2V9ZyQg  SourceTopic: test-topic State: ACTIVE   SourceTopicId: fioeiyhiTzOX8gSMeHuT4Q StoppedSequenceNumber: 0        StateTime: 2025-03-26 15:38:46
        Partition: 0    State: ACTIVE   LocalLogEndOffset: 0    LastFetchSourceHighWatermark: 0 Lag: 0  TimeSinceLastFetchMs: 606
        Partition: 1    State: ACTIVE   LocalLogEndOffset: 1    LastFetchSourceHighWatermark: 1 Lag: 0  TimeSinceLastFetchMs: 751
        Partition: 2    State: ACTIVE   LocalLogEndOffset: 0    LastFetchSourceHighWatermark: 0 Lag: 0  TimeSinceLastFetchMs: 630
        Partition: 3    State: ACTIVE   LocalLogEndOffset: 0    LastFetchSourceHighWatermark: 0 Lag: 0  TimeSinceLastFetchMs: 782
        Partition: 4    State: ACTIVE   LocalLogEndOffset: 0    LastFetchSourceHighWatermark: 0 Lag: 0  TimeSinceLastFetchMs: 678
        Partition: 5    State: ACTIVE   LocalLogEndOffset: 0    LastFetchSourceHighWatermark: 0 Lag: 0  TimeSinceLastFetchMs: 591
```

If there is no lag, promote the topic!

* Promote mirror topic and check status:
```shell
kubectl exec kafka-0 -n destination -it \
  -- kafka-mirrors --promote --topics test-topic --bootstrap-server localhost:9092

kubectl exec kafka-0 -n destination -it \
  -- kafka-mirrors --describe --topics test-topic --pending-stopped-only --bootstrap-server localhost:9092
```

* Produce some data into newly promoted topic:
```shell
kubectl exec kcat -it -- bash -c "date | \
  kcat -b kafka.destination:9092 -t test-topic -P"
```

* Reverse the link:
```shell
kubectl exec kafka-0 -n destination -it \
  -- kafka-mirrors --bootstrap-server localhost:9092 --link two-way-link --reverse-and-start
```

* Consume from original topic (now mirror-topic) and verify the new message with a different timestamp has been mirrored:
```shell
kubectl exec kcat -it -- bash -c "date | \
  kcat -b kafka.source:9092 -t test-topic -C -e"
```

For more details also see [cluster-link](../cluster-link).
