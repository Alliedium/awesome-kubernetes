# Installing scalable PostgreSQL via Kubernetes operator

## Prerequisites


- Add two nodes (agents) to the cluster

```
k3d node create demo-agent -c demo --replicas 2
```

- Get the cluster nodes

```
k3d node list
kubectl get nodes
```

## Steps


### 1. Create namespace ```example-api``` 	

```
kubectl create namespace example-api
```
	
### 2. Install ```postgres-operator``` and ```postgres-operator-ui``` via Helm Charts

**From OpenLens** interface perform the following steps which are equivalent to
[CLI installation instructions](https://github.com/zalando/postgres-operator/blob/master/docs/quickstart.md#helm-chart)

Open menu 'File-->Preferences', tab 'Kubernetes', section 'Helm Charts' at the bottom, button ```Add Custom Helm Repo```

Add repo for postgres-operator

- Helm repo name: postgres-operator-charts

- URL: https://opensource.zalando.com/postgres-operator/charts/postgres-operator

- click ```Add```

Add repo for postgres-operator-ui

- Helm repo name: postgres-operator-ui-charts

- URL: https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui

- click ```Add```

Close the menu tab


Helm / Charts, Search 'postgres', install to the namespace ```example-api```

- postgres-operator

- postgres-operator-ui with the value of ```targetNamespace``` changed to ```'*'```

Check the changed value from Helm / Releases


### 3. See new Custom Resource Definitions 

Custom Resources / acid.zalan.do / postgresql


### 4. Create new PostgreSQL cluster

Network / Services --> namespace: 'example-api', service: 'postgres-operator-ui'

Forward port, open in browser the web console

**From browser on local machine**

Go to Tab 'New cluster', fillout the fields

	Name: enter your <cluster_name> (e.g. ```pg-demo```)
	Namespace: choose 'example-api' (available because of ```targetNamespace: '*'``` for the ui)
	Owning team: default 'acid', the team's name, editable. It will be a prefix for Kubernetes resources names
	Number of instances: 3
	Master load balancer: uncheck 
	Replica load balancer: uncheck
	Enable connection pool: check
	Volume size: 1 (GiB)
	+ Users: testuser
	+ Databases: testdb
	Resources: 100,500,100,1000

Click 'Validate' in the up-right

See the manifest in the left pane 'Cluster YAML definition'

Click 'Create cluster' in the up-right

The Kubernetes resources will be created

**Remark**. The button 'Edit' in the up-right leads to an edit page 
where you can edit settings and apply changes without stopping the PostgreSQL cluster 


### 5. Watch how Postgres cluster is creating in OpenLens 
- Workloads / StatefulSets
- Custom Resources / acid.zalan.do / postgresql


### 6. Install Spring Boot API

Make ```example-api``` active namespace and apply the manifests

```
kubectl ns example-api
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

**From OpenLens**

Add Helm Custom Repo, name: ```runix```, URL: ```https://helm.runix.net```

Create namespace ```pgadmin4```

Install [Helm Chart 'pgadmin4'](http://artifacthub.io/packages/helm/runix/pgadmin4) to the namespace ```pgadmin4``` 
with changed ```env.email``` value to something with domain non-```local```, e.g. ```pgadmin@letmein.org```

**Remark 1**. If the Helm Chart 'pgadmin4' is not seen, hit ```<Ctrl+R>``` (menu 'View-->Reload')

**Remark 2**. The [defalut](https://artifacthub.io/packages/helm/runix/pgadmin4#configuration) value for ```env.email``` is ```chart@example.local```. 
It has domain ```local```, which is considered by pgadmin as non-safe, so pgdamin doesn't start


### 9. Check pgadmin4 ```env.email``` value

Helm / Releases	--> namespace: 'pgadmin4', click on 'pgadmin4-<digital_suffix>'

Right pane with installation properties will be opened

See 'Values' section on the right pane 

**Remark**. If there are shown the values from previous Postgres operator, 
check and uncheck several times 'User-supplied values only'. 
It's a possibly a bug in OpenLens 

Find ```env:``` section with the field in it ```email: pgadmin@letmein.org```

Fix also ```password``` from this section 


### 10. Open pgadmin4 web console on local machine

Network / Services --> namespace: 'pgadmin4', click on 'pgadmin4-<digital_suffix>'

Forward port, open in browser

Log in via ```env.email``` and ```env.password``` values fixed in the previous step


### 11. Connect to server

**From OpenLens**

Config /Secrets --> namespace: 'example-api', click on 'postgres.<postgres_cluster_name>' (with the name os the Postgres cluster)

(postgres_cluster_name: ```acid-pg-demo``` in our example, it can be seen via Services)

Fix username, password, full DNS name of the service
(```acid-pg-demo.example-api.svc.cluster.local``` in our example) 


**From pgadmin web console**

Create a new server connection

Use the fixed username, password, full DNS name

## Cleanup

```
kubectl delete namespace example-api
kubectl delete namespace pgadmin4
```




