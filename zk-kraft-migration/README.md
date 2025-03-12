# Zookeeper to KRaft Migration with CFK

## Documentation and Articles
* Background: https://www.confluent.io/de-de/blog/zookeeper-to-kraft-with-confluent-kubernetes/
* Nice Blog Post by Strimzi: https://strimzi.io/blog/2024/03/21/kraft-migration/
* CP Migration: https://docs.confluent.io/platform/current/installation/migrate-zk-kraft.html
* CFK Migration: https://docs.confluent.io/operator/current/co-migrate-kraft.html
* Official Examples: https://github.com/confluentinc/confluent-kubernetes-examples/tree/master/migration/KRaftMigration

## Steps
* Deploy initial CP:
```shell
kubectl create ns kraft
kubectl apply -f certs.yml
kubectl apply -f cp-initial.yml
```
* Start *ZK to KRaft* migration:
```shell
kubectl apply -f migrationjob.yaml
```
* Watch logs and status:
```shell
kubectl get kmj kraft-migration -n kraft -oyaml -w
kubectl logs -l app=confluent-operator -f -n confluent
```
* Manually proceed after dual-write phase:
```shell
kubectl annotate kmj kraft-migration \
  platform.confluent.io/kraft-migration-trigger-finalize-to-kraft=true \
  --namespace kraft
```
* Once done, save new CRs:
```shell
kubectl get kafkas -n kraft -o yaml >kafka.yaml
kubectl get kraftcontrollers -n kraft -o yaml >kraft.yaml
```
* Release CR lock:
```shell
kubectl annotate kmj kraft-migration -n kraft platform.confluent.io/kraft-migration-release-cr-lock=true --overwrite
```
* Delete Zookeepers:
```shell
kubectl delete zookeepers zookeeper -n kraft
```