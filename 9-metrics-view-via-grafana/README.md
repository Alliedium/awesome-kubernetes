# Installing PostgreSQL with metrics view via Grafana

## Prerequisites

Please follow the steps from [Prerequisites](../README.md#prerequisites) prior to executing the commands below.
Besides, 

- Delete the namespace ```example-api``` in the case it exists

```
kubectl delete namespace example-api
```

- Install [Helm](https://helm.sh/) if it is not installed yet. On Manjaro Linux, run the command

```
yay -S helm --noconfirm
```

Otherwise, see [intallation instructions](https://helm.sh/docs/intro/install/)


## Steps

### 1. Install PostgreSQL via Helm Chart with postgres_exporter tool

[Helm](https://helm.sh/) is a convenient tool, like a package manager, 
for deploying applications with complex structure in Kubernetes, 
see also [github](https://github.com/helm/helm#helm)

[PostgreSQL](https://www.postgresql.org/)
is the world's most advanced Open Source Relational Database

PostgreSQL Server Exporter ([postgres_exporter](https://github.com/prometheus-community/postgres_exporter)) is an exporter of PostgreSQL server metrics for 
[Prometheus](https://prometheus.io/docs/introduction/overview/).

**From CLI**

```
helm repo add bitnami https://charts.bitnami.com/bitnami
```
```
helm repo update
```

[Bitnami](https://bitnami.com/)
is a leading provider of prepackaged open source software that runs natively in various platforms, including the major public clouds, laptops, 
and [Kubernetes](https://bitnami.com/stacks/helm)

```
helm upgrade --install postgresql bitnami/postgresql \
  --namespace example-api --create-namespace \
  --set auth.database=example-api \
  --set metrics.enabled=true \
  --cleanup-on-fail --wait
```

Namespace ```example-api``` should be created, in which there should be created also resources

- Pod ```postgresql-0```
- StatefulSet ```postgresql```
- one ConfigMap
- two Secrets
- three Services
- PersistentVolumeClaim ```data-postgresql-0```
- Helm Release ```postgresql```

### 2. Install the Spring Boot API

**From CLI**

Activate the namespace ```example-api```

```
kubectl ns example-api
```

Change to the example directory and apply the manifests

```
kubectl apply -f db-configmap.yaml
kubectl apply -f api-deployment.yaml
kubectl apply -f api-service.yaml

```

### 3. Check the Spring Boot API installation

**From OpenLens**

Check that the Pod ```api-<suffix>``` in the namespace ```example-api``` is running


**From browser on Local machine**

Open the URL ```http://127.0.0.1:7080```

The 'Simple Spring Boot API' page should be opened


### 4. Check the postgres_exporter installation

**From OpenLens**

Network/Services --> Namespace: ```example-api```, Service: ```postgresql-metrics```

Forward port, open in browser

The page 'Postgres exporter' with 'Metrics' link should be displayed

Open the 'Metrics' link, metrics information in the text form should be displayed

Find ```pg_up``` in the text, there should be a line ```pg_up 1``` meaning that the last scrape of metrics from PostgreSQL was able to connect to the server


### 5. Prometheus should be installed via Lens metrics. 

**From OpenLens**

Click in the left pane ```k3d-demo``` cluster, then in drop-down list choose 'Settings'

Settings page will be opened

In the left pane of the page, choose 'Lens Metrics'

The tab 'Lens Metrics' will be opened

Make sure that all the three switches are ON. 

**Remark.** If you are making the steps **not** for the first time, renew the Prometheus instalation:
- switch OFF all the switches
- click 'Uninstall' button
- wait untill the objects are uninstalled
- switch ON all the switches
- click 'Apply' button

Prometheus can be seen in Workloads/StatefulSets.


### 6. Configure Prometheus to scrape the metircs from postgres_exporter

**From CLI**

Install [yq](https://github.com/mikefarah/yq) package

```
yay -S go-yq --noconfirm
```

Add postgres_exporter scrape settings to Prometheus configuration map

- Put to a variable Prometheus configuration map mainfest supplemented by postgres_exporter scrape settings

```
PROMETHEUS_YAML=$(kubectl -n lens-metrics get configmap/prometheus-config -o "jsonpath={.data['prometheus\.yaml']}" | yq eval '.scrape_configs += [{"job_name": "postgres-exporter", "kubernetes_sd_configs": [{"role": "service", "namespaces": {"names": ["example-api"]}}], "relabel_configs": [{"source_labels": ["__meta_kubernetes_service_annotation_prometheus_io_scrape"], "action": "keep", "regex": true}]}]' - | sed  "s|\"|'|g")
```

- Apply the manifest from the variable

```
kubectl -n lens-metrics get configmap/prometheus-config -o yaml | yq eval '.data."prometheus.yaml" = "'"${PROMETHEUS_YAML}"'"' - | kubectl apply -f -
```

### 7. Check that postgres_exporter scrape settings were added to Prometheus

**From OpenLens**

Config/ConfigMaps, click on ```prometheus-config```, see YAML.

There should be a section at the bottom

```
      - job_name: postgres-exporter
        kubernetes_sd_configs:
          - role: service
            namespaces:
              names:
                - example-api
        relabel_configs:
          - source_labels: 
	      -__meta_kubernetes_service_annotation_prometheus_io_scrape
            action: keep
            regex: true
 ```


### 8. Scale down and up Prometheus StatefulSet

**From CLI**

```
kubectl -n lens-metrics scale --replicas=0 statefulset/prometheus
```

```
kubectl -n lens-metrics scale --replicas=1 statefulset/prometheus
```


### 9. Check that Prometheus is scraping the metircs from postgres_exporter

**From OpenLens**

Network/Services --> Namespace: ```lens-metrics```, Service: ```prometheus```

Forward port, open in browser

The Prometheus page will be opened

In the top menu click 'Status' and choose 'Targets' in drop-down list

The 'Targets' page will be opened

Click 'Collapse All' button in menu below the 'Targets' title

See that ```postgres-exporter``` target is in the page


### 10. Install Grafana

[Grafana](https://github.com/grafana/grafana) is an open-source platform for monitoring and observability. Grafana allows you to query, visualize, alert on and understand your metrics no matter where they are stored  

**From OpenLens**

Create new namespace ```grafana```

Install Grafana to the namespace ```grafana``` via Helm chart


### 11. Get Grafana admin's password from the secret

Config/Secrets --> Namespace: ```grafana```,
click on the secret ```grafana-<digital_suffix>-admin``` 
	
The right pane with secret properties will be opened
    
On the right pane, find the field ```GF_SECURITY_ADMIN_PASSWORD```

Click at 'Show' button to the right of the field
	
Copy field value to the clipboard


### 12. Open Grafana in browser

Network/Services --> Namespace: ```grafana```, Service: ```grafana-<digital_suffix>```

Forward port, open in browser

Enter login 'admin', paste the password taken from the secret ```grafana-<digital_suffix>-admin``` on the previous step


### 13. Add Prometheus datasource to Grafana

**On the Grafana page in browser**

Hover the mouse pointer on gear wheel sign at the bottom part of the left toolbar

Click 'Data sources' record

Configuration page, tab 'Data sources' will be opened

Click 'Add data source' button

Time series databases list will be opened

Choose 'Prometheus'

The form 'Data sources / Prometheus', tab 'Settings' will be opened

Enter the URL: ```http://prometheus.lens-metrics.svc.cluster.local```

Click 'Save & test' button at the bottom of the form

Wait until the field above the button displays record 'Data source is working'


### 14. Import PostgreSQL Dashboard to Grafana 

Hover the mouse pointer on four squares sign at the top part of the left toolbar

Click 'Dashboards' record

Dashboards page, tab 'Browse' will be opened

At the button 'New' open the drop-down list and choose 'Import'

Enter the URL ```https://grafana.com/grafana/dashboards/9628-postgresql-database/``` into 'Import via grafana.com' field 

Click 'Load' button

In the field 'DS_PROMETHEUS' at the bottom, choose the 'Prometheus' data source

Click 'Import' button

**You are done**, the 'PostgreSQL Database' dashboard with the metrics will be displayed
