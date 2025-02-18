# Scale down DC1 brokers
kubectl annotate kafka kafka -n dc1 platform.confluent.io/block-reconcile=true
kubectl scale statefulset kafka -n dc1 --replicas=0
