# Only pods, no persistence due to ephemeral volume

Please perform the steps mentioned in [Prerequisites](../README.md#prerequisites).

## Initial actions

Create a namespace and make it default

```
kubectl create namespace example-api
kubectl ns example-api

```

## Deployment
```
kubectl apply -f db-pod.yaml
kubectl wait pod database-pod --for condition=Ready --timeout=90s
DATABASE_POD_IP=$(kubectl get pod database-pod --template '{{.status.podIP}}')
cat api-pod-template.yaml | sed "s/<database-pod-ip>/${DATABASE_POD_IP//./-}/" | kubectl apply -f -
kubectl wait pod api-pod --for condition=Ready --timeout=90s
kubectl port-forward api-pod 7880:80
```

## Cleanup

Delete the namespace created above:

```
kubectl delete namespace example-api
```

## Advantages

- Now volume with database data belongs only to database
- Components are separated: we are able to update the api app without restarting database (and losing its data)

## Disadvantages

- Still no persistence, data may be lost!
- Still not scalable
- If database is restarted, its pod IP changes, so we have to restart also the app, much more complex way to connect the app to DB
- Still bad way of how the app is exposed outside the cluster
- Still much copy-pasting of parameters
- Password is hard-coded
