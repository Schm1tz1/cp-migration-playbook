#!/usr/bin/env bash

echo "Producing test data..."

kubectl exec kcat -it -- bash -c "cat /dev/urandom | \
  tr -dc 'a-zA-Z0-9' | fold -w 128 | head -n 10000 | \
  kcat -b kafka.source:9092 -t test-topic -P"

kubectl exec kcat -it -- bash -c "cat /dev/urandom | \
  tr -dc 'a-zA-Z0-9' | fold -w 128 | head -n 10000 | \
  kcat -b kafka.source:9092 -t test-topic-1 -P"

kubectl exec kcat -it -- bash -c "echo 1234:test-record |\
  kcat -b kafka.source:9092 -t test-topic-2 -K: -P"

echo "Setting up Cluster Link via CLI..."

cat <<EOF >./clink.properties
bootstrap.servers=kafka.source.svc.cluster.local:9092
consumer.offset.sync.enable=true
consumer.group.prefix.enable=false
auto.create.mirror.topics.enable=true
metadata.max.age.ms=30000
acl.sync.enable=false
EOF

kubectl cp ./clink.properties kafka-0:/tmp/clink.properties -n destination
rm ./clink.properties

kubectl exec kafka-0 -n destination -it --\
  kafka-cluster-links --bootstrap-server localhost:9092 --create --link manual-link \
  --config-file /tmp/clink.properties \
  --consumer-group-filters-json '{"groupFilters": [{ "name": "*", "patternType": "LITERAL", "filterType": "INCLUDE"}]}' \
  --topic-filters-json '{"topicFilters":[{"name": "*","patternType": "LITERAL","filterType": "INCLUDE"}]}'

kubectl exec kafka-0 -n destination -it --\
  kafka-cluster-links --bootstrap-server localhost:9092 --describe

kubectl exec kafka-0 -n destination -it --\
  kafka-mirrors --bootstrap-server localhost:9092 --describe --links manual-link