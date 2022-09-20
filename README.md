# Prerequisites

1. Create a cluster with a registry

```
k3d cluster create demo --k3s-arg "--no-deploy=traefik@server:*" --registry-create demo-registry:0.0.0.0:12345 --port 7080:8080@loadbalancer
```

2. Build and push a Docker image (it is assumed that current folder is `.k8s`)


```
docker build --file ../api/docker/Dockerfile.prod -t localhost:12345/example-api:0.1.0 ../api
docker push localhost:12345/example-api:0.1.0
```

3. Create a namespace and make it default

```
kubectl create namespace example-api
kubectl ns example-api

```

Each time it is necessary to remove previous resources to be able to deploy new ones, please execute

```
kubectl delete namespace example-api
kubectl create namespace example-api
```

# Deployment variants

## 1. Single pod with sidecar, no persistence due to ephemeral volume

```
cd ./1-single-pod-with-ephemeral-volume
kubectl apply -f api-pod.yaml
kubectl wait pod api-pod --for condition=Ready --timeout=90s
kubectl port-forward api-pod 7880:80
cd ..
```

### Disadvantages

- No persisence, data may be lost!
- Not scalable, containers may crash with stopping the whole pod
- Not secure, volume is shared between all containers
- Not possible to update and restart the app without relaunching database
- Very unstable way to expose the app and the latter is only to the host
- Configuration parameters are copy-pasted
- Password is hard-coded

## 2. Only pods, no persistence due to ephemeral volume

```
cd ./2-pods-with-ephemeral-volume
kubectl apply -f db-pod.yaml
kubectl wait pod database-pod --for condition=Ready --timeout=90s
DATABASE_POD_IP=$(kubectl get pod database-pod --template '{{.status.podIP}}')
cat api-pod.yaml | sed "s/<database-pod-ip>/${DATABASE_POD_IP//./-}/" | kubectl apply -f -
kubectl wait pod api-pod --for condition=Ready --timeout=90s
kubectl port-forward api-pod 7880:80
cd ..
```

### Advantages

- Now volume with database data belongs only to database
- Components are separated: now crashing of one component does not lead immediately to stopping the other

### Disadvantages

- Still no persistence, data may be lost!
- Still not scalable
- If database is restarted, its pod IP changes, so we have to restart also the app,
much more complex way to connect the app to DB
- Still bad way of how the app is exposed outside the cluster
- Still much copy-pasting of parameters
- Password is hard-coded

## 3. Added services and persistence via PVC

```
cd ./3-services-with-pvc
kubectl apply -f db-pvc.yaml
kubectl apply -f db-pod.yaml
kubectl apply -f db-service.yaml
kubectl apply -f api-pod.yaml
kubectl apply -f api-service.yaml
cd ..
```

### Advantages

- Components are separated
- At last persistence of database data
- Easy and stable way of how the app connects to DB
- Easy and stable way to expose the app outside the cluster, now it is possible to implement a way to reach the app not only from the host

### Disadvantages

- Still not scalable
- Still much copy-pasting of parameters
- Password is hard-coded

## 4. ReplicaSets, Readiness and Liveness probes

```
cd ./4-replicasets-readiness-liveness
kubectl apply -f db-pvc.yaml
kubectl apply -f db-replicaset.yaml
kubectl apply -f db-service.yaml
kubectl apply -f api-replicaset.yaml
kubectl apply -f api-service.yaml
cd ..
```

### Advantages

- Both components are separated and scalable, possiblity to monitor readiness and liveness of components
- Database data is persisted
- Very stable way of how the app connects to DB
- Very stable and reliable way to expose the app outside the cluster
 

### Disadvantages

- Still much copy-pasting of parameters
- Password is hard-coded
- Persistent volume is shared between all database pods, thus, impossibility to effectively scale database
- Impossibility to smoothly update to a new version of the app

## 5. Deployment, StatefulSet, ConfigMap, Secret

```
cd ./5-deployment-statefulset-configmap-secret
kubectl apply -f db-config.yaml
kubectl apply -f db-secret.yaml
kubectl apply -f db-service.yaml
kubectl apply -f api-service.yaml
kubectl apply -f db-statefulset.yaml
kubectl apply -f api-deployment.yaml
cd ..
```

### Advantages

- Both components are scalable, possiblity to monitor readiness and liveness of components
- Database data is persisted
- Very stable way of how the app connects to DB
- Very stable and reliable way to expose the app outside the cluster
- Configuration parameters are not copy-pasted
- Password is in a secret, we have a way to conceal it from some non-admin users (will be discussed later)
- Persistent volumes per each DB pod
- It is possible to roll out a new version of the app smoothly
