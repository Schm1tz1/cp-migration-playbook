# Set final DC2 Ingress
kubectl apply -f ./networking/ingress-cp-traefik-terminate-dc2-final.yaml

# Remove DC1 Ingress
kubectl delete -f ./networking/ingress-cp-traefik-terminate-dc1.yaml
