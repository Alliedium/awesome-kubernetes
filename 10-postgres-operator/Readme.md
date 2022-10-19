# Installing scalable PostgreSQL via Kubernetes operator

## Prerequisites


- Delete previously created cluster

```
k3d cluster delete demo
```

- Create new k3d ```demo``` cluster with 3 nodes and local container registry

```
k3d cluster create demo -s 3 --k3s-arg "--no-deploy=traefik@server:*" --registry-create demo-registry:0.0.0.0:12345 --port 7080:8080@loadbalancer
```

- Change to ```.k8s``` folder

- Build (if necessary) and push example-api Docker image to the local container registry 

```
docker build --file ../api/docker/Dockerfile.prod -t localhost:12345/example-api:0.1.0 ../api
docker push localhost:12345/example-api:0.1.0
```

- Extract a minimal kubeconfig for the context k3d-demo

```
kubectl konfig export k3d-demo > ~/.kube/k3d-demo.config
```

- See the contents of the file ~/.kube/k3d-demo.config

```
nano ~/.kube/k3d-demo.config
```

Fix the cluster port on VM, e.g. 36483 for the following example

```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS...
    server: https://0.0.0.0:36483
  name: k3d-demo
...
```

- Logout from the VM

```
exit
```

- Use your ssh connection data and your HOME path on the VM to copy the extracted context via ssh to the local machine.

```<ssh_connection_data>``` can have the form ```<login_on_VM>@<IP_address_of_VM>``` e.g. ```bkarpov@192.168.1.208```, 
or be an alias configured for connection to VM in ```~/.ssh/config```

```<HOME_path>``` is the absolute path to your HOME directory on the VM, e.g. ```/home/bkarpov```

```
scp <ssh_connection_data>:<HOME_path>/.kube/k3d-demo.config .
```

e.g. ```scp bkarpov@192.168.1.208:/home/bkarpov/.kube/k3d-demo.config .```

The file should be copied to the working directory on the local machine

- Use your cluster port on VM fixed above to forward from local machine to the VM via ssh tunnel.
Forward also ports: 7080 for Spring Boot API and 9080-->8080 for Visual Studio Code 

```
ssh -L <cluster_port>:127.0.0.1:<cluster_port> \
    -L 7080:127.0.0.1:7080 \
	-L -L 9080:127.0.0.1:8080 \
<ssh_connection_data>
```

e.g. ```ssh -L 36483:127.0.0.1:36483 bkarpov@192.168.1.208```

```
ssh -L 36483:127.0.0.1:36483 \
    -L 7080:127.0.0.1:7080 \
    -L 9080:127.0.0.1:8080 \
bkarpov@192.168.1.208
```

- Use the file ```k3d-demo.config``` in the working directory on local machine to connect to the cluster from OpenLens


## Steps


### 1. Create namespace ```zalando-postgres-ha``` 	
	
	
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


Helm / Charts, Search 'postgres', install to the namespace ```zalando-postgres-ha```

- postgres-operator

- postgres-operator-ui with the value of ```targetNamespace``` changed to ```'*'```

Check the changed value from Helm / Releases


### 3. See new Custom Resource Definitions 

Custom Resources / acid.zalan.do / postgresql


### 4. Create new PostgreSQL cluster

Network / Services --> namespace: 'zalando-postgres-ha', service: 'postgres-operator-ui'

Forward port, open in browser the web console

**From browser on local machine**

Go to Tab 'New cluster', fillout the fields

	Name: enter your <cluster_name> (e.g. ```pg-demo```)
	Namespace: choose 'zalando-postgres-ha' (available because of ```targetNamespace: '*'``` for the ui)
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


### 5. Watch how the cluster is creating in OpenLens 
- Workloads / StatefulSets
- Custom Resources / acid.zalan.do / postgresql


### 6. Install Spring Boot API

Activate the namespace ```zalando-postgres-ha```

Change to ```.k8s/10-postgres-operator``` folder 

Apply the manifests

```
kubectl apply -f db-configmap.yaml
kubectl apply -f api-deployment.yaml
kubectl apply -f api-service.yaml
```

### 7. Check the Spring Boot API installation

Wait unitl the pod ```api-<suffix>``` in the namespace ```zalando-postgres-ha``` is running

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


### 11. Connect to the server

**From OpenLens**

Config /Secrets --> namespace: 'zalando-postgres-ha', click on 'postgres.<postgres_cluster_name>' (with the name os the Postgres cluster)

(postgres_cluster_name: ```acid-pg-demo``` in our example, it can be seen via Services)

Fix username, password, full DNS name of the service
(```acid-pg-demo.zalando-postgres-ha.svc.cluster.local``` in our example) 


**From pgadmin web console**

Create a new server connection

Use the fixed username, password, full DNS name

## Cleanup actions

```
kubectl delete namespace zalando-postgres-ha
kubectl delete namespace pgadmin4
```




