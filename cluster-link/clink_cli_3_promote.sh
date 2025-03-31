#!/usr/bin/env bash

kubectl exec kafka-0 -n destination -it \
  -- kafka-mirrors --promote --link manual-link --bootstrap-server localhost:9092 --force

kubectl exec kafka-0 -n destination -it \
  -- kafka-topics --bootstrap-server localhost:9092 --describe
