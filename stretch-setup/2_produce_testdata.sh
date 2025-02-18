#!/usr/bin/env bash

kubectl apply -f ./bridge/kcat.yaml
kubectl wait --for=condition=ready pod -n bridge kcat

ITERS=100

for i in $(seq 1 $ITERS); do
    echo "Testdata iteration ${i} of ${ITERS}..."
    kubectl exec kcat -it -n bridge -- bash -c "cat /dev/urandom | \
      tr -dc 'a-zA-Z0-9' | fold -w 128 | head -n 1000 | \
      kcat -F /mnt/configs/kcat-cp-ext-ingress.conf -t test -P"
done

kubectl exec kcat -it -n bridge -- bash -c "kcat -F /mnt/configs/kcat-cp-ext-ingress.conf -t test -f '\nHeader: %h \nKey (%K bytes): %k\t\nValue (%S bytes): %s\nTimestamp: %T\tPartition: %p\tOffset: %o\n--\n' -C -e"
