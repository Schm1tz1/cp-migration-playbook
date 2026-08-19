#!/usr/bin/env bash

kubectl exec kafka-0 -n destination -it -- \
  kafka-cluster-links --bootstrap-server localhost:9092 --delete \
    --link manual-link
