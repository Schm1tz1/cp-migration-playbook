#!/usr/bin/env bash

echo "Source:"
kubectl exec schemaregistry-0 -n source -it -- bash -c "curl -k http://localhost:8081/subjects"
echo

echo "Destination:"
kubectl exec schemaregistry-0 -n destination -it -- bash -c "curl -k http://localhost:8081/subjects"
echo
