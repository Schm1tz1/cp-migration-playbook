# Cluster Linking
Official Docs: https://docs.confluent.io/operator/current/co-link-clusters.html
This example convers a setup of 2 CP clusters showing the possibilities of a topic mirroring/migration.

## General Setup
* Execute `./setup.sh` and wait for CP to be up and running and topic to be created.

* Produce random data:
```shell
kubectl exec kcat -it -- bash -c "cat /dev/urandom | \
  tr -dc 'a-zA-Z0-9' | fold -w 128 | head -n 6000000 | \
  kcat -b kafka.source:9092 -t test-topic -P"
```
## ClusterLink Setup using ClusterLink-CR
* Start cluster link:
```shell
kubectl apply -f cluster-link.yaml
```

* Check topics in destination cluster:
```shell
kubectl exec kafka-0 -n destination -it \
  -- kafka-topics --bootstrap-server localhost:9092 --list
kubectl get kafkatopics -A -o wide
```

* Check mirror topic status:
```shell
kubectl exec kafka-0 -n destination -it \
  -- kafka-replica-status --topics test-topic --include-mirror --bootstrap-server localhost:9092
```
If there is no lag, promote the topic!

* Promote mirror topic:
```shell
kubectl apply -f cluster-link-promote.yaml
```

* Check topics:
```shell
$ kubectl get kafkatopics -A -o wide                                                           ~
NAMESPACE   NAME                        REPLICAS   PARTITION   STATUS    CLUSTERID                AGE     KAFKACLUSTER
confluent   clink-test-topic-5ede0ef2   1          6           CREATED   yGfY2iW8R4ysMkMJLN2hpw   3m31s
confluent   test-topic                  1          6           CREATED   ebAE9XJGS5-iVrJKvJX1-g   52m     confluent/kafka
```
Check details with `kubectl describe` or `kubectl get -o yaml`. Note the difference between CR name and topic name:
```yaml
apiVersion: platform.confluent.io/v1beta1
kind: KafkaTopic
metadata:
  ...
  name: clink-test-topic-5ede0ef2
  namespace: confluent
  ...
spec:
  configs:
    cleanup.policy: delete
    delete.retention.ms: "86400000"
    ...
  kafkaRestClassRef:
    name: kafka-new-rest
    namespace: confluent
  name: test-topic
  partitionCount: 6
  replicas: 1
status:
  ...
```

* Consume from old topic, then delete old topic, consume from new topic, verify deletion and compare:
```shell
$ kubectl exec kcat -n confluent -it -- kcat -b kafka:9092 -t test-topic -C -e >old.txt
$ kubectl delete -f topic.yaml
kafkatopic.platform.confluent.io "test-topic" deleted
$ kubectl get kafkatopics -A -o wide
NAMESPACE   NAME                        REPLICAS   PARTITION   STATUS    CLUSTERID                AGE   KAFKACLUSTER
confluent   clink-test-topic-5ede0ef2   1          6           CREATED   yGfY2iW8R4ysMkMJLN2hpw   12m
$ kubectl exec kcat -n confluent -it -- kcat -b kafka-new:9092 -t test-topic -C -e >new.txt
$ diff old.txt new.txt
```

## ClusterLink Setup using ClusterLink-CLI
* Create manual Cluster Link and mirror topics:
```shell
kubectl exec kafka-0 -n destination -it \
  -- kafka-cluster-links --bootstrap-server localhost:9092 --create --link manual-link --config bootstrap.servers=kafka.source.svc.cluster.local:9092

kubectl exec kafka-0 -n destination -it \
  -- kafka-mirrors --create --mirror-topic test-topic --link manual-link --bootstrap-server localhost:9092
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
If there is no lag, promote the topic!

* Promote mirror topic and check status:
```shell
kubectl exec kafka-0 -n destination -it \
  -- kafka-mirrors --promote --topics test-topic --bootstrap-server localhost:9092

kubectl exec kafka-0 -n destination -it \
  -- kafka-mirrors --describe --topics test-topic --pending-stopped-only --bootstrap-server localhost:9092
```
* List Kafka Topics and note that the newly promoted topics are not listed:
```shell
$ kubectl get kafkatopics -A
NAMESPACE   NAME             REPLICAS   PARTITION   STATUS    CLUSTERID                AGE
confluent   test-topic       1          6           CREATED   Kh49VqjhTomwNiBhiqIEAA   10m
```
Verify that cluster ID belongs to the old cluster:
```shell
$ kubectl exec kafka-0 -n confluent -it \
  -- curl -k http://localhost:8090/kafka/v3/clusters | jq '.data[].cluster_id'
"Kh49VqjhTomwNiBhiqIEAA"
```
Apply `topic-new.yaml` by CR:
```shell
kubectl apply -f topic-new.yaml
```
and list again:
```shell
$ kubectl get kafkatopics -A
NAMESPACE   NAME             REPLICAS   PARTITION   STATUS    CLUSTERID                AGE
confluent   test-topic       1          6           CREATED   Kh49VqjhTomwNiBhiqIEAA   10m
confluent   test-topic-new   1          6           CREATED   PX_J8slKTsmGZNfNMSEkOw   1m
```

* Delete old topic:
```shell
kubectl delete -f topic.yaml
```

### Working with conflicing and patched CRs
WARNING !!! Do not try to delete a CR with the same name and namespace combination and only changing ownership (e.g. by patching kafkaClusterRef.name). It will result in conflicts because on k8s lever ownership is preserved. This will cause deletion of the topic in the cluster that was set as an owner upon creation - example:
```shell
$ kubectl patch kafkatopic -n confluent test-topic-new -p '{"spec": {"kafkaClusterRef": {"name": "kafka", "namespace": "confluent"}}}' --type merge
$ kubectl get kafkatopic test-topic-new -n confluent -o yaml
apiVersion: platform.confluent.io/v1beta1
kind: KafkaTopic
metadata:
  ...
  name: test-topic-new
  namespace: confluent
  ownerReferences:
  - apiVersion: platform.confluent.io/v1beta1
    blockOwnerDeletion: true
    controller: true
    kind: Kafka
    name: kafka-new
    uid: 584a6dc0-0805-4149-8ba9-7999a272b886
  resourceVersion: "384966"
  uid: f20b13d0-0b25-4b2a-83d5-24ca58a8210f
spec:
  configs:
    cleanup.policy: delete
  kafkaClusterRef:
    name: kafka
    namespace: confluent
  name: test-topic
  partitionCount: 6
  replicas: 1
status:
  appState: Created
  conditions:
  - lastProbeTime: "2024-07-17T15:35:49Z"
    lastTransitionTime: "2024-07-17T15:35:49Z"
    message: Application is created
    reason: Created
    status: "True"
    type: platform.confluent.io/app-ready
  kafkaCluster: confluent/kafka
  kafkaClusterID: Kh49VqjhTomwNiBhiqIEAA
```
Calling `kubectl delete kafkatopic test-topic-new -n confluent` will leave the topic in **ERROR** state because of conflicting ownership settings and delete the log directories on the original owner resource (`kafka-new` is this case).

## Advanced Cluster Link Configuration
* Auto-sync all topics and consume groups:
```yaml
consumer.offset.sync.enable=true
auto.create.mirror.topics.enable=true
auto.create.mirror.topics.filters={"topicFilters":[{"name": "*","patternType": "LITERAL","filterType": "INCLUDE"}]}
consumer.group.prefix.enable=false
acl.sync.enable=false
```
* For destination-initiated CL simply create the link in the destination cluster and set both `bootstrap.servers` accordingly

## Other helpful commands

* Create topic via CR:
```shell
kubectl apply -f topic.yaml
```

* Create topic manually:
```shell
kubectl exec kafka-0 -n confluent -it \
  -- kafka-topics --bootstrap-server localhost:9092 --create --topic test-topic
```
Note: (Re-)Creating an existing topic via CR apply will "import" it to the tracked CRs of the operator and won't delete ay existing topic.

* Check cluster links:
```shell
kubectl exec kafka-0 -n destination -it \
  -- kafka-cluster-links --list --bootstrap-server localhost:9092
```

* Check mirrors:
```shell
kubectl exec kafka-0 -n destination -it \
  -- kafka-mirrors --list --bootstrap-server localhost:9092
```

* Delete cluster links:
```shell
kubectl exec kafka-0 -n destination -it \
  -- kafka-cluster-links --list --bootstrap-server localhost:9092
```