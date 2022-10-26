# Installing scalable PostgreSQL via Kubernetes operator

## Prerequisites

- Add two nodes (agents) to the cluster

```
k3d node create demo-agent -c demo --replicas 2
```

**Remark**.
One can create a new cluster with three server nodes for this example instead of adding two agent nodes as describbed above. To do this, one can run the command

```
k3d cluster create demo-10 -s 3 --k3s-arg "--no-deploy=traefik@server:*" --registry-create demo-registry:0.0.0.0:102345 --port 1080:8080@loadbalancer
```

In contrast to the existing demo cluster, where [Kubernetes Control Plane](https://kubernetes.io/docs/concepts/overview/components/) is only on one node, the new cluster will have Kubernetes Control Plane on all nodes. 
Please take into account that while using the latter cluster you need to adjust all the instructions given in [Prerequisites](../README.md#prerequisites) as well as those pointed below by replacing ports ```12345``` and ```7080``` by ```102345``` and ```1080```, respectively.


- Get the cluster nodes

```
k3d node list
kubectl get nodes
```

## Steps


### 1. Install ```postgres-operator``` via Helm Chart

```
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo update
helm upgrade --install --cleanup-on-fail postgres-operator postgres-operator-charts/postgres-operator --namespace example-api --create-namespace --set configKubernetes.enable_pod_antiaffinity=true --wait
```

The operator and all its resources will be installed to namespace ```example-api```, which will be created if necessary


### 2. See new Custom Resource Definitions 

**From CLI**

```
kubectl ns example-api
kubectl get crds
```

**From OpenLens**

Custom Resources / acid.zalan.do / postgresql


### 3. Create new PostgreSQL cluster

**From CLI**

```
kubectl apply -f db-crd.yaml
```


### 4. Watch how PostgreSQL cluster is creating

**From CLI**

```
kubectl get statefulsets
kubectl get pods
kubectl get pvc
kubectl get crd postgresqls.acid.zalan.do -o go-template="{{.spec.names.kind}}  {{.spec.names.plural}} "
kubectl get postgresql
kubectl describe postgresql acid-pg-demo
```

**From OpenLens**

- Workloads / StatefulSets
- Workloads / Pods
- Storage / Persistent Volume Claims
- Custom Resources / acid.zalan.do / postgresql

### 5. Look at PostgreSQL cluster manifest via Postgres Operator UI 

**Install ```postgres-operator-ui``` via Helm Chart**

```
helm repo add postgres-operator-ui-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui
helm repo update
helm upgrade --install --cleanup-on-fail postgres-operator-ui postgres-operator-ui-charts/postgres-operator-ui -f postgres-operator-ui_values.yaml --namespace example-api --create-namespace --wait
```

**Remark**. 
Value of ```envs.targetNamespace``` changed to ```'*'``` in the file ```postgres-operator-ui_values.yaml```


**Open ```postgres-operator-ui``` in browser**

Network / Services --> namespace: 'example-api', service: 'postgres-operator-ui'

Forward port, open in browser the web console

**From browser on local machine**

Go to Tab 'PostgreSQL clusters'

Click at 'acid-pg-demo'

See the manifest in the left pane 'Cluster YAML definition'

**Remark**. From the tab 'New cluster' one can create new PostgreSQL cluster instead of applying manifest from CLI (Step 3)

### 6. Install Spring Boot API


```
kubectl apply -f db-configmap.yaml
kubectl apply -f api-deployment.yaml
kubectl apply -f api-service.yaml
```

### 7. Check Spring Boot API installation

Wait until the pod ```api-<suffix>``` in the namespace ```example-api``` is running

**From browser on Local machine**

Open the URL ```http://127.0.0.1:7080```

The 'Simple Spring Boot API' page should be opened

	
### 8. Install pgadmin4 via Helm chart 

**From CLI**

```
helm repo add runix https://helm.runix.net
helm repo update
helm upgrade --install --cleanup-on-fail pgadmin4 runix/pgadmin4 -f pgadmin4_values.yaml --namespace pgadmin4 --create-namespace --wait
```

**Remark**.
The [defalut](https://artifacthub.io/packages/helm/runix/pgadmin4#configuration) value for ```env.email``` is ```chart@example.local```. 
It has domain ```local```, which is considered by pgadmin as non-safe, so pgdamin doesn't start.
In the file ```pgadmin4_values.yaml``` this value is changed to  ```pgadmin@letmein.org```


**Check credentials**

Helm / Releases --> namespace: 'pgadmin4'

Click on 'pgadmin4'

On the left pane, in 'Values' field, check that the value of 
- ```env.email``` is ```pgadmin@letmein.org```
- ```env.password``` is ```123```

**Remark**. If there are shown the values from previous Postgres operator, 
check and uncheck several times 'User-supplied values only'. 
It's possibly a bug in OpenLens 


### 9. Open pgadmin4 web console on local machine

Network / Services --> namespace: 'pgadmin4', click on 'pgadmin4'

Forward port, open in browser

Log in via ```env.email``` and ```env.password``` values checked in the previous step


### 10. Connect to server

**From OpenLens**

Config /Secrets --> namespace: 'example-api', click on 'postgres.<suffix>' (with the name os the Postgres cluster)

Fix username, password, full DNS name of the service
(```acid-pg-demo.example-api.svc.cluster.local``` in our example) 


**From pgadmin web console**

Create a new server connection

Use the fixed username, password, full DNS name

## Cleanup

```
kubectl delete namespace pgadmin4
kubectl delete namespace example-api
```




