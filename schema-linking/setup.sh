#!/usr/bin/env bash

kubectl create namespace source
kubectl create namespace destination

kubectl apply -f cp-source-zk.yaml
kubectl apply -f cp-dest-kraft.yaml

kubectl apply -f schema.yaml