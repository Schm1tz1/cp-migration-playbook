# Patch ZK to use proxy
kubectl patch zookeeper zookeeper --type merge --patch-file patch-zookeepers-pre-migration.yaml -n dc1
