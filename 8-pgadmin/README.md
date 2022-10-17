# Installing pgAdmin

This example is based on the blog [How to Deploy pgAdmin in Kubernetes](https://www.enterprisedb.com/blog/how-deploy-pgadmin-kubernetes).

```
kubectl create namespace pgadmin --dry-run=client -o yaml | kubectl apply -f -
kubectl -n pgadmin apply -f pgadmin-secret.yaml
kubectl -n pgadmin apply -f pgadmin-configmap.yaml
kubectl -n pgadmin apply -f pgadmin-service.yaml
kubectl -n pgadmin apply -f pgadmin-statefulset.yaml
```

To remove the resources it is sufficient to execute
```
kubectl delete namespace pgadmin
```
