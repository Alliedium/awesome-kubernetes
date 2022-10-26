# Simple job with Minio S3 storage

Please follow the steps from [Prerequisites](../README.md#prerequisites) prior to executing the commands below.
Besides, this example assumes that the [Example 5](../05-deployment-statefulset-configmap-secret) is already deployed and not cleaned up from the cluster.

## Initial actions
```
kubectl apply -f s3-secret.yaml
# install Minio via Helm
helm upgrade --install minio minio \
  --repo https://charts.min.io \
  --set existingSecret=s3-secret \
  --set mode=standalone --set resources.requests.memory=100Mi \
  --set persistence.enabled=true \
  --set persistence.size=1Gi \
  --set 'buckets[0].name=backups,buckets[0].policy=none,buckets[0].purge=false'
```

## Launch job and wait for its completion

```
kubectl apply -f db-backup-job.yaml
kubectl wait --for=condition=complete job/db-backup
```

## Cleanup

```
helm delete minio
kubectl delete -f s3-secret.yaml
```
