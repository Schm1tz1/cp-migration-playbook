#!/usr/bin/env bash

kubectl apply -f change_replica_placement.yaml
kubectl logs -n dc1 -l job-name=change-replica-placement -f
