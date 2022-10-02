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
This is necessary ONLY for examples 1--5 below concerning deployment variants.

For examples 6 and 7 it is assumed that the example 5 is already deployed, instructions on removing resources concerning examples 6, 7 and 8 are given below along the examples themselves.

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
cat api-pod-template.yaml | sed "s/<database-pod-ip>/${DATABASE_POD_IP//./-}/" | kubectl apply -f -
kubectl wait pod api-pod --for condition=Ready --timeout=90s
kubectl port-forward api-pod 7880:80
cd ..
```

### Advantages

- Now volume with database data belongs only to database
- Components are separated: we are able to update the api app without restarting database (and losing its data)

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
kubectl apply -f db-configmap.yaml
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

# Backup jobs configuration variants

## 6. Simple job with Minio S3 storage

### Initial actions
```
cd ./6-job-with-minio
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

### Launch job and wait for its completion

```
kubectl apply -f db-backup-job.yaml
kubectl wait --for=condition=complete job/db-backup
```

### Cleaning actions

```
helm delete minio
kubectl delete -f s3-secret.yaml
cd ..
```

## 7. CronJob with AWS S3 storage

There are two scenarios below for initial actions need to be done before applying manifests to Kubernetes:

- **a)** Using `Localstack` as a substitute for real AWS services (doesn't require using some real AWS account)
- **b)** Using real AWS (as a production-like scenario)
  
### **a)** Using Localstack AWS S3 Bucket

#### Initial actions

Please execute

```
cd ./7-cronjob-with-aws-s3
kubectl apply -f s3-configmap.yaml
kubectl apply -f s3-secret.yaml
# install Localstack via Helm
helm upgrade --install localstack localstack --repo https://helm.localstack.cloud -f localstack-values.yaml --set service.type=LoadBalancer
```

#### Deploy CronJob

```
kubectl apply -f db-backup-cronjob.yaml
```

#### Test CronJob

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
aws --endpoint http://localhost:4566 s3 ls s3://backups --recursive
```

You should see all the files for created backups.

#### Cleaning actions

```
helm delete localstack
kubectl delete -f db-backup-cronjob.yaml
kubectl delete -f s3-secret.yaml
kubectl delete -f s3-configmap.yaml
cd ..
```

### **b)** Initial actions for real AWS S3 Bucket

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
cd ./7-cronjob-with-aws-s3
kubectl apply -f s3-configmap.yaml
kubectl apply -f s3-secret.yaml
```

#### Deploy CronJob

```
kubectl apply -f db-backup-cronjob.yaml
```


#### Test CronJob

Either trigger CronJob manually via some tool like `OpenLens` or execute the following:
```
kubectl create job --from=cronjob/db-backup db-backup-manual-$(openssl rand -hex 3)
```

After this execute

```
aws s3 ls s3://backups --recursive

```

You should see all the files for created backups (you can also view them via [console](https://s3.console.aws.amazon.com/s3/home)).

#### Cleaning actions

```
kubectl delete -f db-backup-cronjob.yaml
kubectl delete -f s3-secret.yaml
kubectl delete -f s3-configmap.yaml
cd ..
```

# Installing useful tools in Kubernetes

## 8. Installing pgAdmin

This example is based on the blog [How to Deploy pgAdmin in Kubernetes](https://www.enterprisedb.com/blog/how-deploy-pgadmin-kubernetes).

```
cd ./8-pgadmin
kubectl create namespace pgadmin --dry-run=client -o yaml | kubectl apply -f -
kubectl -n pgadmin apply -f pgadmin-secret.yaml
kubectl -n pgadmin apply -f pgadmin-configmap.yaml
kubectl -n pgadmin apply -f pgadmin-service.yaml
kubectl -n pgadmin apply -f pgadmin-statefulset.yaml
cd ..
```

To remove the resources it is sufficient to execute
```
kubectl delete namespace pgadmin
```

# Remarks concerning secrets

For many examples above we have used manifests for [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/). And secret values in these manifests were hard coded. But this is just for simplicity, i.e. it is not how secrets are to be handled in real production. The reason is that these hard coded values can be seen by any person having access to respective Git repository which contradicts with an idea of secrets being a secret. 

There are a few different ways to deal with the problem. Here are just two of them (without claiming that these two are the only onces that should be used):

* Using [Sealed Secrets](https://sealed-secrets.netlify.app/). Here we store a special kind of Kubernetes resources named `SealedSecret`. Its manifest contains *encrypted* values that can be decrypted only by the controller running in the target Kubernetes cluster and nobody else (not even the original author). This way onlythe controller is able to obtain the original Secret from the SealedSecret (within the cluster). [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) use [asymmetric cryptography](https://cheapsslsecurity.com/blog/what-is-asymmetric-encryption-understand-with-simple-examples/) to encrypt secrets with a public key while the private key used for decryption is only known to the controller.
* Using [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) along with [Kubernetes](https://docs.aws.amazon.com/eks/latest/userguide/manage-secrets.html). We can [use](https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver.html) a special [AWS Secrets and Configuration Provider ](https://github.com/aws/secrets-store-csi-driver-provider-aws) deployed inside [AWS EKS](https://aws.amazon.com/eks/) Kubernetes cluster (thus, this is an example of how this may be done in production in a cloud). Here we store a special kind of Kubernetes resources named [`SecretProviderClass`](https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver.html#integrating_csi_driver_SecretProviderClass). Its manifest contains information about your secrets and how to display them in the Amazon EKS pod where these secrets are referenced. And, for example, it is possible to [sync](https://secrets-store-csi-driver.sigs.k8s.io/topics/sync-as-kubernetes-secret.html) secrets as a Kubernetes Secret. Another option is to [mount](https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver_tutorial.html) secrets as files on the pod filesystem.

In both cases we do not store secret values *directly* in manifests. But there is a case when it is reasonable to commit `Secret` manifests into the Git repository. This concerns configurations deployed by developers themselves into Kubernetes clusters created also by developers for debugging and development purposes. Here all the secret values may be shared by developers, these values are not *really* hidden. We use [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) for deploying them to comply with production configurations. Pods just reference to these secrets not knowing what are their sources, making their manifests the same both for development and production.

For an additional info also see [Good practices for Kubernetes Secrets](https://kubernetes.io/docs/concepts/security/secrets-good-practices/).
