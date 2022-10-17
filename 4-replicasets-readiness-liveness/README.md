# ReplicaSets, Readiness and Liveness probes

Please perform the steps mentioned in [Prerequisites](../README.md#prerequisites).

## Initial actions

Create a namespace and make it default

```
kubectl create namespace example-api
kubectl ns example-api

```

## Deployment
```
kubectl apply -f db-pvc.yaml
kubectl apply -f db-replicaset.yaml
kubectl apply -f db-service.yaml
kubectl apply -f api-replicaset.yaml
kubectl apply -f api-service.yaml
```

## Cleanup

Delete the namespace created above:

```
kubectl delete namespace example-api
```

## Advantages

- Both components are separated and scalable, possiblity to monitor readiness and liveness of components
- Database data is persisted
- Very stable way of how the app connects to DB
- Very stable and reliable way to expose the app outside the cluster
 

## Disadvantages

- Still much copy-pasting of parameters
- Password is hard-coded
- Persistent volume is shared between all database pods, thus, impossibility to effectively scale database
- Impossibility to smoothly update to a new version of the app
