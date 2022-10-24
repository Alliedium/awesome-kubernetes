# Deployment, StatefulSet, ConfigMap, Secret

Please follow the steps from [Prerequisites](../README.md#prerequisites) prior to executing the commands below.

## Initial actions

Create a namespace and make it default

```
kubectl create namespace example-api
kubectl ns example-api

```

## Deployment
```
kubectl apply -f db-configmap.yaml
kubectl apply -f db-secret.yaml
kubectl apply -f db-service.yaml
kubectl apply -f api-service.yaml
kubectl apply -f db-statefulset.yaml
kubectl apply -f api-deployment.yaml
```

## Cleanup

Delete the namespace created above:

```
kubectl delete namespace example-api
```

## Advantages

- Both components are scalable, possiblity to monitor readiness and liveness of components
- Database data is persisted
- Very stable way of how the app connects to DB
- Very stable and reliable way to expose the app outside the cluster
- Configuration parameters are not copy-pasted
- Password is in a secret, we have a way to conceal it from some non-admin users (will be discussed later)
- Persistent volumes per each DB pod
- It is possible to roll out a new version of the app smoothly
