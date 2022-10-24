# Single pod with sidecar, no persistence due to ephemeral volume

Please follow the steps from [Prerequisites](../README.md#prerequisites) prior to executing the commands below.

## Initial actions

Create a namespace and make it default

```
kubectl create namespace example-api
kubectl ns example-api

```

## Deployment
```
kubectl apply -f api-pod.yaml
kubectl wait pod api-pod --for condition=Ready --timeout=90s
kubectl port-forward api-pod 7880:80
```

## Cleanup

Delete the namespace created above:

```
kubectl delete namespace example-api
```

## Disadvantages

- No persisence, data may be lost!
- Not scalable, containers may crash with stopping the whole pod
- Not possible to update and restart the app without relaunching database
- Very unstable way to expose the app and the latter is only to the host
- Configuration parameters are copy-pasted
- Password is hard-coded
