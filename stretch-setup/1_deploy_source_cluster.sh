#!/usr/bin/env bash

kubectl apply -f ./dc1/dc1-zookeeper-init.yaml
kubectl apply -f ./dc1/dc1-kafka-init.yaml
kubectl apply -f ./networking/ingress-cp-traefik-terminate-dc1.yaml
kubectl apply -f ./dc1/dc1-test-topic.yaml
