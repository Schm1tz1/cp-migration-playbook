#!/usr/bin/env bash

kubectl exec kafka-0 -it -n dc1 -- bash -c "kafka-topics --bootstrap-server kafka:9071 --topic test --describe"
