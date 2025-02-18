zookeepers=(zk0-proxy.bridge zk1-proxy.bridge zk2-proxy.bridge zk10-proxy.bridge zk11-proxy.bridge zk12-proxy.bridge)

for i in ${zookeepers[@]}; do
    echo "${i}"
    kubectl exec kcat -it -n bridge -- bash -c "cat <(echo stat; while true; do sleep 0.01; echo -n '#'; done) - | nc -v $i 2181" 2>&1 | sed 's/\(.*\)/  \1/'
    echo
done

echo "DC1 Kafka ID:"
kubectl exec zookeeper-0 -it -n dc1 -- bash -c "zookeeper-shell localhost:2181 ls /" | grep '\[' | sed 's/\[//g ; s/\]//g'
kubectl exec zookeeper-0 -it -n dc1 -- bash -c "zookeeper-shell localhost:2181 get /mrc/cluster/id"

echo "DC2 Kafka ID:"
kubectl exec zookeeper-0 -it -n dc2 -- bash -c "zookeeper-shell localhost:2181 ls /" | grep '\[' | sed 's/\[//g ; s/\]//g'
kubectl exec zookeeper-0 -it -n dc2 -- bash -c "zookeeper-shell localhost:2181 get /mrc/cluster/id"
