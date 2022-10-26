# CronJob with AWS S3 storage

Please follow the steps from [Prerequisites](../README.md#prerequisites) prior to executing the commands below.
Besides, this example assumes that the [Example 5](../05-deployment-statefulset-configmap-secret) is already deployed and not cleaned up from the cluster.

There are two scenarios below for initial actions need to be done before applying manifests to Kubernetes:

- **a)** Using `Localstack` as a substitute for real AWS services (doesn't require using some real AWS account)
- **b)** Using real AWS (as a production-like scenario)
  
## **a)** Using Localstack AWS S3 Bucket

### Initial actions

Please execute

```
kubectl apply -f s3-configmap.yaml
kubectl apply -f s3-secret.yaml
# install Localstack via Helm
helm upgrade --install localstack localstack --repo https://helm.localstack.cloud -f localstack-values.yaml --set service.type=LoadBalancer
```

### Deploy CronJob

```
kubectl apply -f db-backup-cronjob.yaml
```

### Test CronJob

Either trigger CronJob manually via some tool like `OpenLens` or execute the following:
```
kubectl create job --from=cronjob/db-backup db-backup-manual-$(openssl rand -hex 3)
```

After this either create port forwarding for `localstack` service via some tool like `OpenLens` or execute

```
kubectl port-forward svc/localstack 4566:4566 &
disown
```
and then this please run
```
export AWS_ACCESS_KEY_ID=local
export AWS_SECRET_ACCESS_KEY=local

aws --endpoint http://localhost:4566 s3 ls s3://backups --recursive
```

You should see all the files for created backups.

### Cleanup

```
helm delete localstack
kubectl delete -f db-backup-cronjob.yaml
kubectl delete -f s3-secret.yaml
kubectl delete -f s3-configmap.yaml
```

## **b)** Initial actions for real AWS S3 Bucket

The prerequisites are

- to create an AWS account (or to use some already existing one)
- to [install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) `AWS CLI` (on Manjaro it will be already installed after launching the scripts from the [repo](https://github.com/Alliedium/awesome-linux-config))
- to [configure](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html) `AWS CLI` to interact with AWS via so called *programmatic access*

Then you need to perform the following steps:

* in AWS S3 in some region create a bucket to store backups, its name may be any that is allowed to be chosen (the only restriction in AWS is that this name should not coincide with some already used by someone in AWS)
* in AWS IAM [create](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html) a user with programmatic access
* [attach](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_manage-attach-detach.html) the following inline policy for this user providing full access to the bucket created above (please change `<bucket-name>` below by the name of your bucket used for storing backups):
   
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::<bucket-name>"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::<bucket-name>/*"
            ]
        }
    ]
}
```

* change values in `s3-secret.yaml` by real values of `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` taken for this user
* change values in `s3-configmap.yaml` by the values according the comments in that file

After this execute
```
kubectl apply -f s3-configmap.yaml
kubectl apply -f s3-secret.yaml
```

### Deploy CronJob

```
kubectl apply -f db-backup-cronjob.yaml
```


### Test CronJob

Either trigger CronJob manually via some tool like `OpenLens` or execute the following:
```
kubectl create job --from=cronjob/db-backup db-backup-manual-$(openssl rand -hex 3)
```

After this execute

```
aws s3 ls s3://backups --recursive

```

You should see all the files for created backups (you can also view them via [console](https://s3.console.aws.amazon.com/s3/home)).

### Cleanup

```
kubectl delete -f db-backup-cronjob.yaml
kubectl delete -f s3-secret.yaml
kubectl delete -f s3-configmap.yaml
```
