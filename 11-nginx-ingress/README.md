## Prerequisites
We assume that
- All kubectl commands are executed from Manjaro Linux VM
- Kubernetes cluster is set up via
https://github.com/techno-tim/k3s-ansible Ansible playbook according to https://github.com/Alliedium/devops-course-2022/tree/main/40_setting_up_production_like_kubernetes_cluster_part_5_15_dec_2022
with MetalLB and KubeVIP installed.
- MetalLB is configured to allocate IP addresses from 10.150.0.40 - 10.150.0.60 range
  and these IP addresses are reachable from both Manjaro VM and our
  home lab router.
- Our home lab router is reachable from Internet via at least single public IP address
  allocated to us by our internet provider 
- All the tools used in examples from https://github.com/Alliedium/springboot-api-rest-example/tree/master/.k8s
are installed

## 1. Reaching Nginx Hello World pod via HTTP from local VM
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
10.150.0.50 hello-http-0.devops-ingress-0.intranet
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
  namespace: nginx-ingress-exp 
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
  namespace: nginx-ingress-exp 
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

## References
- https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx 
- https://spacelift.io/blog/kubernetes-ingress
- https://www.nginx.com/blog/automating-multi-cluster-dns-with-nginx-ingress-controller/
- https://www.nginx.com/blog/implementing-openid-connect-authentication-kubernetes-okta-and-nginx-ingress-controller/#Creating-SSO-Integrations-for-Multiple-Apps
- https://docs.giantswarm.io/advanced/ingress/configuration/
