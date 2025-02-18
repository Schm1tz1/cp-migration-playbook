#!/usr/bin/env bash

kubectl get ns dc1 && {
    kubectl delete secret tls-schmitzi-ingress -n dc1
} || {
    kubectl create ns dc1
}

kubectl get ns dc2 && {
    kubectl delete secret tls-schmitzi-ingress -n dc2
} || {
    kubectl create ns dc2
}

kubectl get ns bridge || kubectl create ns bridge

kubectl get secret tls-schmitzi-ingress -o yaml | sed 's/namespace: default/namespace: dc1/g' | kubectl apply -f -
kubectl get secret tls-schmitzi-ingress -o yaml | sed 's/namespace: default/namespace: dc2/g' | kubectl apply -f -

# kubectl get secret confluent-operator-licensing -o yaml | sed 's/namespace: default/namespace: dc/g' | kubectl apply -f -
# kubectl get secret confluent-operator-licensing -o yaml | sed 's/namespace: default/namespace: dc2/g' | kubectl apply -f -
