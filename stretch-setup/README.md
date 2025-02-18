# NGINX Reverse Proxy Setup for Stretch-Cluster with mixed TLS networking and limited ingress capabilites
* https://docs.nginx.com/nginx/admin-guide/security-controls/securing-tcp-traffic-upstream/

## Prepare setup:
```shell
./0_prepare.sh
```

## Namespaced Operator Deployments
```shell
helm upgrade --install confluent-operator \
  confluentinc/confluent-for-kubernetes \
  --set namespaced=true \
  --set licenseKey=... \
  --namespace dc1

helm upgrade --install confluent-operator \
  confluentinc/confluent-for-kubernetes \
  --set namespaced=true \
  --set licenseKey=... \
  --namespace dc2
```

## Setup and Migration Scenario
* DC1 will be set up as the source cluster, some data to be produced to the topic `test`.
* Cluster is then stretched across DC1 and DC2 using Ingress and Proxy for Zookeeper communication and Replication
* All partitions are migrated to DC2
* DC1 brokers are shut down (scaled to 0 replicas)
* ZK configurations and Kafka-ZK dependencies are switched back to non-stretched DC2 cluster
* Ingress and listeners are changed to default and DC1 clsuter is deleted.

* Steps for migration:
```shell
# Prepare namespaces and TLS secrets
0_prepare.sh

# Deploy DC1
1_deploy_source_cluster.sh

# Produce some 100k test messages to `test` topics
2_produce_testdata.sh

# Set up stretch setup. One step at a time, wait until finished!
3a_deploy_proxy.sh
3b_deploy_zookeepers-dc2.sh
3c_reconfigure_zookeepers.sh
3d_check_zookeepers.sh
3e_reconfigure_brokers.sh
3f_deploy_brokers-dc2.sh

# Verify replica placement
4_check_placement.sh

# The actual migration. Might need to re-run to see the logs (if the pod is not ready yet).
5_perform_migration.sh

# Post-Migration - you can double-check the placement or simply trust rebalancer. Switch Ingress to DC2 and scale down DC1 brokers
6a_switch_ingress.sh
6b_scale_down_brokers.sh

# Reconfigure ZK and ZK deps in brokers
7_reconfigure_zookeepers.sh
8_reconfigure_brokers.sh

# Finally: delete DC1 cluster
9_finalize.sh
```

## Optional: Deploy C3 for some monitoring (dc1 or dc2):
```shell
kubectl apply -f dc1/dc1-c3.yaml
# or DC2 (to monitor after migration):
kubectl apply -f dc2/dc2-c3.yaml
```