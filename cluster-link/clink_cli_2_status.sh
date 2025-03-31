#!/usr/bin/env bash

kubectl exec kafka-0 -n destination -it --\
  kafka-cluster-links --bootstrap-server localhost:9092 --describe

kubectl exec kafka-0 -n destination -it --\
  kafka-mirrors --bootstrap-server localhost:9092 --describe --links manual-link