#!/usr/bin/env bash

kubectl create namespace source
kubectl create namespace destination

# Soruce Cluster
# kubectl apply -f cp-source-ccs-zk.yaml
kubectl apply -f cp-source-zk.yaml

# Destination Cluster
# kubectl apply -f cp-dest-zk.yaml
kubectl apply -f cp-dest-kraft.yaml

kubectl apply -f topic.yaml
kubectl apply -f kcat.yaml
