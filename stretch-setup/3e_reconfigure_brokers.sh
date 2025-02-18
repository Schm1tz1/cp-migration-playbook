# Patch Kafka to use external replication and ZK proxy
kubectl patch kafka kafka --type merge --patch-file patch-brokers-dc1-pre-migration.yaml -n dc1
