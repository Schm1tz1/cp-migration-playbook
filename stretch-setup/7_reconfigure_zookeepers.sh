# Patch ZK to use new (DC2) only
kubectl patch zookeeper zookeeper --type merge --patch-file patch-zookeeper-post-migration.yaml -n dc1
kubectl patch zookeeper zookeeper --type merge --patch-file patch-zookeeper-post-migration.yaml -n dc2
