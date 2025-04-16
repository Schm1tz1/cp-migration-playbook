#!/usr/bin/env bash

kubectl create namespace source
kubectl create namespace destination

# Soruce Cluster
kubectl apply -f ../cluster-link/cp-source-zk.yaml

# Destination Cluster
kubectl apply -f ../cluster-link/cp-dest-kraft.yaml

kubectl apply -f ../cluster-link/topic.yaml
kubectl apply -f ../cluster-link/kcat.yaml
