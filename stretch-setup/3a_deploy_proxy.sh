# Deploy ingress components
kubectl apply -f ./networking/ingress-zk-dc1-traefik-terminate.yaml
kubectl apply -f ./networking/ingress-zk-dc2-traefik-terminate.yaml
kubectl apply -f ./networking/ingress-kafka-replication-terminate.yaml
kubectl apply -f ./networking/ingress-cp-traefik-terminate-dc2.yaml

# Deploy proxy component
kubectl apply -f ./bridge/bridge-nginx-ingress-conf.yaml
kubectl apply -f ./bridge/bridge-nginx.yaml
