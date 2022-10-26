# 1. Prerequisites

- Create a cluster with a registry

```
k3d cluster create demo --k3s-arg "--no-deploy=traefik@server:*" --registry-create demo-registry:0.0.0.0:12345 --port 7080:8080@loadbalancer
```

- Build and push a Docker image (it is assumed that current folder is `.k8s`)


```
docker build --file ../api/docker/Dockerfile.prod -t localhost:12345/example-api:0.1.0 ../api
docker push localhost:12345/example-api:0.1.0
```

# 2. Deployment variants

| Example | Details |
|------|-------|
| [Example 1](./01-single-pod-with-ephemeral-volume) | Single pod with sidecar, no persistence due to ephemeral volume |
| [Example 2](./02-pods-with-ephemeral-volume) | Only pods, no persistence due to ephemeral volume |
| [Example 3](./03-services-with-pvc) | Added services and persistence via PVC |
| [Example 4](./04-replicasets-readiness-liveness) | ReplicaSets, Readiness and Liveness probes |
| [Example 5](./05-deployment-statefulset-configmap-secret) | Deployment, StatefulSet, ConfigMap, Secret |

## Remarks concerning secrets

For the last example above as well as for some examples below we use manifests for [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/). And secret values in these manifests are hard coded. But this is just for simplicity, i.e. it is not how secrets are to be handled in real production. The reason is that these hard coded values can be seen by any person having access to respective Git repository which contradicts with an idea of secrets being a secret. 

There are a few different ways to deal with the problem. Here are just two of them (without claiming that these two are the only onces that should be used):

* Using [Sealed Secrets](https://sealed-secrets.netlify.app/). Here we store in Git a special kind of Kubernetes resources named `SealedSecret`. Its manifest contains *encrypted* values that can be decrypted only by the controller running in the target Kubernetes cluster and nobody else (not even the original author). This way only the controller is able to obtain the original Secret from the SealedSecret (within the cluster). [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) use [asymmetric cryptography](https://cheapsslsecurity.com/blog/what-is-asymmetric-encryption-understand-with-simple-examples/) to encrypt secrets with a public key while the private key used for decryption is only known to the controller.
* Using [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) along with [Kubernetes](https://docs.aws.amazon.com/eks/latest/userguide/manage-secrets.html). We can [use a CSI driver](https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver.html), namely its AWS-based implementation called [AWS Secrets and Configuration Provider ](https://github.com/aws/secrets-store-csi-driver-provider-aws) deployed inside [AWS EKS](https://aws.amazon.com/eks/) Kubernetes cluster (thus, this is an example of how this may be done in production in a cloud). Here we store in Git a special kind of Kubernetes resources named [`SecretProviderClass`](https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver.html#integrating_csi_driver_SecretProviderClass). Its manifest contains information about your secrets and how to display them in the Amazon EKS pod which references these secrets. And, for example, it is possible to [sync]((https://secrets-store-csi-driver.sigs.k8s.io/topics/sync-as-kubernetes-secret.html)) secrets as a Kubernetes Secret. Another option is to [mount](https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver_tutorial.html) secrets as files on the pod filesystem.

Both of these approaches allow us to avoid storing original secret values *directly* inside manifests. However there are cases when it is acceptable to store `Secret` manifests (along with the original secret values) directly inside Git repository. This is when manifests are used only for development purposes (some experiments for instance) and are designed for being deployed in a development cluster and not in production. However the main problem with such an approach is that it can lead to having two sources of truth (read two sets of manifests) - one for development and one for production. In our opinion such approach should be avoided as much as possible (instead we should use production ways to deal with secretes even for development). With all that being said, when such *insecure* is used all the secret values may be shared by developers and the secret values are not *really* hidden. To make the rest of the manifests as environment agnostic as possible we should use [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) for deploying them to comply with production configurations. Pods just reference these secrets not knowing what their sources are thus making the rest of the manifests the same both for both development and production.

For more details see [Good practices for Kubernetes Secrets](https://kubernetes.io/docs/concepts/security/secrets-good-practices/) and the blog [How to use AWS Secrets & Configuration Provider with your Kubernetes Secrets Store CSI driver](https://aws.amazon.com/ru/blogs/security/how-to-use-aws-secrets-configuration-provider-with-kubernetes-secrets-store-csi-driver/).

# 3. Backup jobs configuration variants

Both examples below assume that the [Example 5](./05-deployment-statefulset-configmap-secret) is already deployed and not cleaned up from the cluster.

| Example | Details |
|------|-------|
| [Example 6](./06-job-with-minio) | Simple job with Minio S3 storage |
| [Example 7](./07-cronjob-with-aws-s3) | CronJob with AWS S3 storage |

# 4. Installing useful tools in Kubernetes

| Example | Details |
|------|-------|
| [Example 8](./08-pgadmin) | Installing pgAdmin |

# 5. Using aready existing Helm charts and operators

| Example | Details |
|------|-------|
| [Example 9](./09-metrics-view-via-grafana) | Installing PostgreSQL with metrics view via Grafana |
| [Example 10](./10-zalando-postgres-ha-operator) | Installing scalable PostgreSQL via Kubernetes operator |
