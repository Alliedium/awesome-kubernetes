# Added services and persistence via PVC

Please follow the steps from [Prerequisites](../README.md#prerequisites) prior to executing the commands below.

## Initial actions

Create a namespace and make it default

```
kubectl create namespace example-api
kubectl ns example-api

```

## Deployment
```
kubectl apply -f db-pvc.yaml
kubectl apply -f db-pod.yaml
kubectl apply -f db-service.yaml
kubectl apply -f api-pod.yaml
kubectl apply -f api-service.yaml
```

## Cleanup

Delete the namespace created above:

```
kubectl delete namespace example-api
```

## Advantages

- Components are separated
- At last persistence of database data
- Easy and stable way of how the app connects to DB
- Easy and stable way to expose the app outside the cluster, now it is possible to implement a way to reach the app not only from the host

## Disadvantages

- Still not scalable
- Still much copy-pasting of parameters
- Password is hard-coded
