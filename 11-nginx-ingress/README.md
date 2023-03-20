## Prerequisites
We assume that
- All kubectl commands are executed from Manjaro Linux VM
- Kubernetes cluster is set up via
https://github.com/techno-tim/k3s-ansible Ansible playbook according to https://github.com/Alliedium/awesome-devops/tree/main/40_setting_up_production_like_kubernetes_cluster_part_5_15_dec_2022
with MetalLB and KubeVIP installed.
- MetalLB is configured to allocate IP addresses from 10.150.0.40 - 10.150.0.60 range
  and these IP addresses are reachable from both Manjaro VM and our
  home lab router.
- Our home lab router is reachable from Internet via at least single public IP address
  allocated to us by our internet provider 
- All Kubernetes tools described in
  https://github.com/Alliedium/awesome-devops/tree/main/11_k8s_dev_tools_kubectl_krew_vscode_15-sep-2022
  are installed

## 1. Exposing service via HTTP mode within intranet 
### Install NGINX Ingress controller via Helm
Make sure that your current context points to the correct cluster (use
`kubectl ctx`) and then
run 
```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install nginx-ingress --namespace nginx-ingress --create-namespace \ 
 ingress-nginx/ingress-nginx --cleanup-on-fail --set controller.service.loadBalancerIP='10.150.0.50'
```

and finally watch the status of NGINX Ingress controller installation
via
```
kubectl --namespace nginx-ingress get services -o wide -w nginx-ingress-ingress-nginx-controller
```

### Use `/etc/hosts` file to imitate DNS server
Let us add two following records to `/etc/hosts` file on Manjaro VM
```
10.150.0.50 hello-http-0.devops-ingress-0.intranet
10.150.0.50 hello-http-1.devops-ingress-0.intranet
```
so that we can reach our NGINX Ingress controller IP using two different
DNS names.

### Create 2 different backend services
We will create all backend pods and services in `nginx-ingress-example-1`
namespace:

```
kubectl create ns nginx-ingress-example-1
kubectl config set-context --current --namespace=nginx-ingress-example-1
```
Now run 2 pods with names `hello-http-0` and `hello-http-1`
```
kubectl run hello-http-0 --image=nginxdemos/hello --port=80
kubectl run hello-http-1 --image=nginxdemos/hello --port=80
```
based on `nginxdemos/hello` Docker image and then create 2 services for
each of them:
```
kubectl expose pods hello-http-0 --name hello-http-0-svc
kubectl expose pods hello-http-1 --name hello-http-1-svc
```
### Create 2 different Ingresses for each of the backends
Run

```
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-http-0-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: hello-http-0.devops-ingress-0.intranet
      http:
        paths:
          - pathType: Prefix
            backend:
              service:
                name: hello-http-0-svc
                port:
                  number: 80
            path: /

EOF
```
and

```
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-http-1-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: hello-http-1.devops-ingress-0.intranet
      http:
        paths:
          - pathType: Prefix
            backend:
              service:
                name: hello-http-1-svc
                port:
                  number: 80
            path: /

EOF
```
and make sure Ingresses are created:

```
kubectl get ingress
```
You an also describe each of them:
```
kubectl describe ingress hello-http-0-ingress
kubectl describe ingress hello-http-1-ingress
```

## Access backends using their DNS names
If everything is configured correctly you should see that
```
w3m http://hello-http-0.devops-ingress-0.intranet -dump
```
displays the webpage for `hello-http-0` while
```
w3m http://hello-http-1.devops-ingress-0.intranet -dump
```
displays the webpage for `hello-http-1`.

## 2. Exposing service Ingress with TLS certificate issued by Cert-Manager via DNS-01 challenge 
### Assumptions
We assume that all steps from the previous example are already performed
and backend services (and pods) are created in `nginx-ingress-example-2`
namespace:

```
kubectl create ns nginx-ingress-example-2
kubectl config set-context --current --namespace=nginx-ingress-example-2

kubectl run hello-http-0 --image=nginxdemos/hello --port=80
kubectl run hello-http-1 --image=nginxdemos/hello --port=80

kubectl expose pods hello-http-0 --name hello-http-0-svc
kubectl expose pods hello-http-1 --name hello-http-1-svc
```



### Follow the same steps as in https://github.com/Alliedium/awesome-nginx#register-a-new-domain-using-route53
and create the following 3 records of type "A" in Route53 hosted zone:
- `nginx0-manjaro.devopshive.link`
- `nginx1-manjaro.devopshive.link`
- `nginx2-manjaro.devopshive.link`

all pointing to public IP of your home lab router

### Expose ports 443 and 80 on your NGINX Ingress to internet
This should be done similarly to https://github.com/Alliedium/awesome-nginx#expose-ports-8443-and-8080-on-nginx-host-to-internet
```
PUBLIC IP: 80 -> INGRESS CONTROLLER IP: 80
PUBLIC IP: 9443 -> INGRESS CONTROLLER IP: 443
```
We assume that INGRESS CONTROLLER IP is `10.150.0.50` (the same as in the
previous example). In your case it might be different.

### Create Ingress instances for accessing backend services via HTTP
Make sure that current namespace is `nginx-ingress-example-2`:
```
kubectl config set-context --current --namespace=nginx-ingress-example-2
```
and then run

```
cat <<EOF | kubectl apply -f -                 
apiVersion: networking.k8s.io/v1
kind: Ingress      
metadata:
  name: hello-http-0-ingress
spec:
  ingressClassName: nginx
  rules:                        
    - host: nginx0-manjaro.devopshive.link                        
      http:             
        paths:                            
          - pathType: Prefix
            backend:
              service:
                name: hello-http-0-svc
                port:
                  number: 80
            path: /        
          
EOF
```
and

```
cat <<EOF | kubectl apply -f -                 
apiVersion: networking.k8s.io/v1
kind: Ingress      
metadata:
  name: hello-http-1-ingress
spec:
  ingressClassName: nginx
  rules:                        
    - host: nginx1-manjaro.devopshive.link                        
      http:             
        paths:                            
          - pathType: Prefix
            backend:
              service:
                name: hello-http-1-svc
                port:
                  number: 80
            path: /        
          
EOF
```

### Check availability of backend services via HTTP:

If all the configuration in the sections above is performed correctly
the commands
```
w3m http://nginx0-manjaro.devopshive.link -dump
w3m http://nginx1-manjaro.devopshive.link -dump
```
should show pages corresponding to backend services while
```
w3m http://nginx2-manjaro.devopshive.link -dump
```
should show 404 error.

### Install Cert Manager
Add Cert Manager repository via
```
helm repo add jetstack https://charts.jetstack.io
helm repo update
```
and then install Cert Manager itself via Helm:

```
helm upgrade --install \                         
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.11.0 \
  --set installCRDs=true \
  --cleanup-on-fail
```
Please refer to https://cert-manager.io/docs/installation/helm/ for
detailed explanation of installation and de-installation process.

Now install `cmctl` via
```
sudo pacman -S cmctl
```
and run the following command to wait until Cert Manager API is up and running:

```
cmctl check api --wait=2m
Not ready: the cert-manager CRDs are not yet installed on the Kubernetes API server
Not ready: the cert-manager webhook deployment is not ready yet
Not ready: the cert-manager webhook deployment is not ready yet
The cert-manager API is ready
```
See https://cert-manager.io/docs/installation/verify/ for more details
about Cert Manager API verification.

### Create ClusterIssuer configured to use LetsEncrypt's DNS-01
challange 

Since in our case Kubernetes cluster runs outside of AWS we need a special user with programmatic access only that has permissions to create and delete records in our new hosted zone.
Please follow instructions from https://github.com/Alliedium/awesome-devops/blob/main/17_networks_ssl-termination_acme_route53_06-oct-2022/README.md to create the user but make sure to use this policy instead 
(please make sure to replace `YOUR-HOSTED-ZONE-ID` with ID of your
hosted zone):

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "route53:GetChange",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/YOUR-HOSTED-ZONE-ID"
    }
  ]
}
```
(see
https://cert-manager.io/docs/configuration/acme/dns01/route53/#set-up-an-iam-role
for details).

Now let us create a secret in `cert-manager` namespace containing
secret access key for our IAM user (please make sure to replace
`YOUR-SECRET-KEY` with secret key of the user):

```
kubectl create secret generic acme-bot-route53-credentials-secret \
    --from-literal=secret-access-key='YOUR-SECRET-KEY' --namespace cert-manager
```

Finally, let us create 2 instances of ClusterIssuer, one for LetsEncrypt
staging environment (see
https://letsencrypt.org/docs/staging-environment/)
```
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    email: your@email.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-issuer-account-key-staging
    solvers:
    - selector:
        dnsZones:
          - "devopshive.link"
      dns01:
        route53:
          region: us-east-1
          accessKeyID: YOUR-ACCESS-KEY-ID 
          hostedZoneID: YOUR-HOSTED-ZONE-ID
          secretAccessKeySecretRef:
            name: acme-bot-route53-credentials-secret
            key: secret-access-key
EOF
```

and one - for LetsEncrypt production environment (see
https://letsencrypt.org/docs/rate-limits/)

```
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: your@email.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-issuer-account-key-prod
    solvers:
    - selector:
        dnsZones:
          - "devopshive.link"
      dns01:
        route53:
          region: us-east-1
          accessKeyID: YOUR-ACCESS-KEY-ID 
          hostedZoneID: YOUR-HOSTED-ZONE-ID
          secretAccessKeySecretRef:
            name: acme-bot-route53-credentials-secret
            key: secret-access-key
EOF
```
(please make sure to replace 
- `your@email.com`
- region
- `YOUR-ACCESS-KEY-ID`
- `YOUR-HOSTED-ZONE-iD`

with valid values for your case).

We can check that 2 instances of ClusterIssuer are successfully
created:

```
kubectl get clusterissuer
# NAME                  READY   AGE
# letsencrypt-prod      True    1m
# letsencrypt-staging   True    1m
```
Please note that Cert Manager supports two types of certificate issuers:  `ClusterIssuer` 
and `Issuer` (see https://cert-manager.io/docs/concepts/issuer/). In
this example we created `ClusterIssuer` to be able to issue certificates
for ingresses created in arbitrary namespaces (`ClusterIssuer` is not
namespaced).

### Create TLS-enabled Ingress instances linked with Cert-Managed
Since all backend services run in `nginx-ingress-example-2` namespace
let us make sure that we switch to that namespace:

```
kubectl config set-context --current --namespace=nginx-ingress-example-2
```

We will create two ingress instances - one for `hello-http-0-svc`
backend service with TLS issued via `letsencrypt-staging`
`ClusterIssuer`: 
```
cat <<EOF | kubectl apply -f -                 
apiVersion: networking.k8s.io/v1
kind: Ingress      
metadata:
  name: hello-http-0-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - nginx0-manjaro.devopshive.link
    secretName: nginx0-devopshive-tls  
  rules:                        
    - host: nginx0-manjaro.devopshive.link                        
      http:             
        paths:                            
          - pathType: Prefix
            backend:
              service:
                name: hello-http-0-svc
                port:
                  number: 80
            path: /        
          
EOF
```
and one ingress of `hello-http-1-svc` backend service with TLS
certificated issued by `letsencrypt-prod` `ClusterIssuer`:

```
cat <<EOF | kubectl apply -f -                 
apiVersion: networking.k8s.io/v1
kind: Ingress      
metadata:
  name: hello-http-1-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - nginx1-manjaro.devopshive.link
    secretName: nginx1-devopshive-tls  
  rules:                        
    - host: nginx1-manjaro.devopshive.link                        
      http:             
        paths:                            
          - pathType: Prefix
            backend:
              service:
                name: hello-http-1-svc
                port:
                  number: 80
            path: /        
          
EOF
```

Once `Ingress` instances are created we should be able to see that our certificates are
ready:
```
kubectl get certificate
# NAME                    READY   SECRET                  AGE
# nginx0-devopshive-tls   True    nginx0-devopshive-tls   1m
# nginx1-devopshive-tls   True    nginx1-devopshive-tls   2m
```
in just a few minutes after ingress creation. If certificates never get
to state `Ready` it is recommended to look at Kubernetes events:
```
kubectl get events --namespace cert-manager
```

### Access our backend services via HTTPS
Accessing `hello-http-0-svc` backend service via
```
w3m https://nginx0-manjaro.devopshive.link:9443 -dump
```
results in `unable to get local issuer certificate` error which can be
overridden by answering `y` to `accept?` question. This was expected
because for the first `Ingress` we used LetsEncrypt staging environment
which doesn't issue real certificates.

Accessing `hello-http-1-svc` via
```
w3m https://nginx1-manjaro.devopshive.link:9443 -dump
```
works just fine because the second `Ingress` we created with TLS
certificate issued by LetsEncrypt production environment.

Finally, if we run
```
w3m https://nginx2-manjaro.devopshive.link:9443 -dump
```
we receive `self-signed certificate` warning because NGINX Ingress
controller presents a fake self-signed certificate (see
https://kubernetes.github.io/ingress-nginx/user-guide/tls/#default-ssl-certificate) for all unknown
hosts. If we accept this certificate we'll see 404 error. 

The above can be confirmed via running
```
curl -vkI https://nginx0-manjaro.devopshive.link:9443
curl -vkI https://nginx1-manjaro.devopshive.link:9443
curl -vkI https://nginx2-manjaro.devopshive.link:9443
```
## 3. Synchronizing Ingresses with Route53 automatically via External-DNS

### Assumptions
We assume that Cert Manager is installed and configured according to
instructions in the previous example. We also assume that 
 backend services (and pods) are created in `nginx-ingress-example-3`
namespace:

```
kubectl create ns nginx-ingress-example-3
kubectl config set-context --current --namespace=nginx-ingress-example-3

kubectl run hello-http-0 --image=nginxdemos/hello --port=80
kubectl run hello-http-1 --image=nginxdemos/hello --port=80

kubectl expose pods hello-http-0 --name hello-http-0-svc
kubectl expose pods hello-http-1 --name hello-http-1-svc
```
### High Level Picture
This example is built on top of the previous example and adds
integration of NGINX Ingress Controller with External-DNS (see
https://github.com/kubernetes-sigs/external-dns) and Route53
(https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md). The purpose of this
integration is to enable an automatic synchronization of Ingresses with
Route53 Records Sets and Hosted Zone so that when we create an new (or
delete an existing)
Ingress the corresponding record in Hosted Zone is created (deleted)
automatically. This, combined with Cert Manager, significantly
simplifies exposing Kubernetes services to Internet as all we need
to do to make a service publicly available via HTTPS is to create an
Ingress pointing to that service. Both Cert Manager and External DNS
will take care of the rest. 


### Configuring programmatic access from Kubernetes to Route53
As in the previous example we will require IAM account with programmatic
access. This account will have to have the following policy attached:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "route53:GetChange",
            "Resource": "arn:aws:route53:::change/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets",
                "route53:ListResourceRecordSets"
            ],
            "Resource": "arn:aws:route53:::hostedzone/YOUR-HOSTED-ZONE-ID"
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones"
            ],
            "Resource": "*"
        }
    ]
}
```
where `YOUR-HOSTED-ZONE-ID` needs be be replaced with your Route53 Hosted Zone
ID (see
https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md#iam-policy).
This policy is very similar to the policy from the previous example
(with the exception that it allows allows listing hosted zones).

We will also require a special namespace `external-dns` (where we will
install External DNS):
```
kubectl create namespace external-dns
```
and a secret created with programmatic access keys

```
kubectl create secret generic external-dns \                                                                            
    --from-literal=secret-access-key='YOUR-SECRET-ACCESS-KEY' --from-literal=aws_access_key_id='YOUR-ACCESS-KEY-ID'
```
where `YOUR-SECRET-ACCESS-KEY` and `YOUR-ACCESS-KEY-ID` need to be
replaced with programmatic access key and key id.

### Installing External DNS
The official documentation of Exteranl DNS suggests that we install it
via applying Kubernetes manifest for Deployment directly (see
https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md#manifest-for-clusters-without-rbac-enabled).

However, in this example we will install External DNS via Helm Chart by
Bitnami (see https://artifacthub.io/packages/helm/bitnami/external-dns).

As the first step we need to add Bitnami Helm repository:
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```
and then use Helm to install External DNS into `external-dns` namespace:


```
helm upgrade --install  external-dns \                                                                                  
  --namespace external-dns --create-namespace \
  --set provider=aws \
  --set aws.zoneType=public \
  --set txtOwnerId=YOUR-HOSTED-ZONE-ID \
  --set policy=sync \
  --set "domainFilters[0]=devopshive.link" \
  --set aws.credentials.accessKeyIDSecretRef.name=external-dns \
  --set aws.credentials.accessKeyIDSecretRef.key=aws_access_key_id \
  --set aws.credentials.secretAccessKeySecretRef.name=external-dns \
  --set aws.credentials.secretAccessKeySecretRef.key=secret-access-key \
  bitnami/external-dns \
  --cleanup-on-fail
```
where
`YOUR-HOSTED-ZONE-ID` needs to be replaced by your Hosted Zone ID and
`devopshive.link` - by your domain name.

The command above sets the following parameters:
- `provider=aws` - as we use Route53 (even though support for other
  providers is available - see
  https://github.com/kubernetes-sigs/external-dns#the-latest-release).
- `aws.zoneType=public` - our `devopshive.link` hosted zone is public
  because we expose our Kubernetes services to Internet. 
- `policy=sync` - we want add records to Route53 when we create
  Ingresses, delete records as we delete Ingresses and update records as
  we update Ingresses. Sometimes you might want to use `upsert-only`
  policy instead (which prohibits Route53 record deletion). 
- `domainFilters[0]=devopshive.link` - we want External DNS to track
  only `devopshive.link` subdomain, its subdomains and nothing else.
- 4 `*SecretRef` parameters specify location of secret (and keys inside
  that secret) where programmatic access credentials for Route53 are
  located. We created that secrets in one of the sections above.

### Creating Ingresses 
Normally, External DNS is used in the clusters deployed in Cloud
Provider's infrastructure where services of type "LoadBalancer" are
automatically given a public external IP. In our case the external IP
given to services of type "LoadBalancer" are take from the pool of
internal IP addresses controlled by MetalLB. Thus, when External DNS
cannot use the external IPs from the services themselves and need to use
our external public IP given to us by our internet provider (of course,
here we assume that we do port-forwarding and firewall configuration on
our home lab router by ourselves). This requires a special handling on our side - we need to let External DNS
know our true external public IP address. This can be done via adding a
special annotation to each of the Ingress instances we create:
```
external-dns.alpha.kubernetes.io/target: x.x.x.x
```

where `x.x.x.x` needs to be replaced by public IP address used by your
router.

Let us define an environment variable `EXTERNAL_IP` containing our
public IP address:
```
export EXTERNAL_IP=x.x.x.x # specify your public IP address here 
```
and let us use it when creating Ingresses for `hello-http-0-svc` using
`letsencrypt-staging` Cluster Issuer (which was configured in the
previous example):

```
cat <<EOF |sed "s/EXTERNAL_IP/$EXTERNAL_IP/g" |kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-http-0-ext-dns-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
    external-dns.alpha.kubernetes.io/target: EXTERNAL_IP
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - nginx0-ext-dns-manjaro.devopshive.link
    secretName: nginx0-ext-dns-devopshive-tls
  rules:
    - host: nginx0-ext-dns-manjaro.devopshive.link
      http:
        paths:
          - pathType: Prefix
            backend:
              service:
                name: hello-http-0-svc
                port:
                  number: 80
            path: /

EOF
```
and Ingress for `hello-http-1-svc` service using `letsencrypt-prod` Cluster
Issuer: 
```
cat <<EOF |sed "s/EXTERNAL_IP/$EXTERNAL_IP/g" |kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-http-1-ext-dns-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    external-dns.alpha.kubernetes.io/target: EXTERNAL_IP
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - nginx1-ext-dns-manjaro.devopshive.link
    secretName: nginx1-ext-dns-devopshive-tls
  rules:
    - host: nginx1-ext-dns-manjaro.devopshive.link
      http:
        paths:
          - pathType: Prefix
            backend:
              service:
                name: hello-http-1-svc
                port:
                  number: 80
            path: /

EOF
```
External DNS reacts to appearance of new Ingress instances quite promptly 
while it might take up to 2-3 minutes for certificates to be issued by
Cert Manager. 

### Testing access from outside
If you try to run 
```
w3m https://nginx0-ext-dns-manjaro.devopshive.link:9443 -dump
```
or
```
w3m https://nginx1-ext-dns-manjaro.devopshive.link:9443 -dump
```
right after creating Ingresses you might see the following errors:
- `w3m: Can't load https://nginx1-ext-dns-manjaro.devopshive.link:9443`
  - this means that External DNS has not yet added "A" record to your
  hosted zone. If you are inpatient you can go to AWS web console and
  periodically update the Resource Record Set for your hosted zone to
  watch the new records being created. Alternatively you can run the
  following command (replace `YOUR-HOSTED-ZONE-ID` with your Hosted Zone
  ID):
  ```
  aws route53  list-resource-record-sets --hosted-zone-id YOUR-HOSTED-ZONE-ID --output json --query "ResourceRecordSets[?Type == 'A']"
  ```

- `self-signed certificate: accept? (y/n)` - this means that Cert
  Manager has not yet issued the certificate for us and NGINX Controller
  uses a fake self-signed certificate as a default. You can run the
  following commands to wait for certificates to be issued:
  ```
  kubectl wait certificates nginx0-ext-dns-devopshive-tls --for condition=Ready --timeout=200s
  kubectl wait certificates nginx1-ext-dns-devopshive-tls --for condition=Ready --timeout=200s
  ```

In both cases you just need to wait a bit more. Once certificates are
ready accessing `hello-http-0-svc` backend service via
```
w3m https://nginx0-manjaro.devopshive.link:9443 -dump
```
results in `unable to get local issuer certificate` error which can be
overridden by answering `y` to `accept?` question. This was expected
because for the first `Ingress` we used LetsEncrypt staging environment
which doesn't issue real certificates.

Accessing `hello-http-1-svc` via
```
w3m https://nginx1-manjaro.devopshive.link:9443 -dump
```
works just fine because the second `Ingress` we created with TLS
certificate issued by LetsEncrypt production environment.


## References
- https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx 
- https://spacelift.io/blog/kubernetes-ingress
- https://www.nginx.com/blog/automating-multi-cluster-dns-with-nginx-ingress-controller/
- https://www.nginx.com/blog/implementing-openid-connect-authentication-kubernetes-okta-and-nginx-ingress-controller/#Creating-SSO-Integrations-for-Multiple-Apps
- https://docs.giantswarm.io/advanced/ingress/configuration/
- https://github.com/techno-tim/k3s-ansible
- https://github.com/Alliedium/awesome-devops/tree/main/40_setting_up_production_like_kubernetes_cluster_part_5_15_dec_2022
- https://github.com/Alliedium/springboot-api-rest-example/tree/master/.k8s
- https://github.com/Alliedium/awesome-nginx#register-a-new-domain-using-route53
- https://github.com/Alliedium/awesome-nginx#expose-ports-8443-and-8080-on-nginx-host-to-internet
- https://cert-manager.io/docs/installation/helm/
- https://cert-manager.io/docs/installation/verify/
- https://github.com/Alliedium/awesome-devops/blob/main/17_networks_ssl-termination_acme_route53_06-oct-2022/README.md
- https://cert-manager.io/docs/configuration/acme/dns01/route53/#set-up-an-iam-role
- https://letsencrypt.org/docs/staging-environment/
- https://letsencrypt.org/docs/rate-limits/
- https://cert-manager.io/docs/concepts/issuer/
- https://kubernetes.github.io/ingress-nginx/user-guide/tls/#default-ssl-certificate
