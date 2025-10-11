# Pod Deployment Guide for EKS Cluster

## 1. Configure kubectl Access

After cluster deployment, configure kubectl to connect:

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name enterprise-eks-cluster

# Verify connection
kubectl get nodes
kubectl get pods --all-namespaces
```

## 2. Deploy Sample Applications

### Simple Nginx Pod
```bash
# Create nginx deployment
kubectl create deployment nginx --image=nginx:latest

# Expose as service
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Check status
kubectl get pods
kubectl get services
```

### Sample YAML Deployment
```yaml
# sample-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app-service
spec:
  selector:
    app: sample-app
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

Apply with:
```bash
kubectl apply -f sample-app.yaml
```

## 3. Deploy Cluster Autoscaler

```bash
# Download and apply cluster autoscaler
curl -o cluster-autoscaler-autodiscover.yaml https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# Edit the file to add your cluster name
sed -i 's/<YOUR CLUSTER NAME>/enterprise-eks-cluster/g' cluster-autoscaler-autodiscover.yaml

# Apply
kubectl apply -f cluster-autoscaler-autodiscover.yaml

# Patch for safe eviction
kubectl patch deployment cluster-autoscaler -n kube-system -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict":"false"}}}}}'

# Verify
kubectl get pods -n kube-system | grep cluster-autoscaler
```

## 4. Deploy AWS Load Balancer Controller

```bash
# Create IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# Create service account
eksctl create iamserviceaccount \
  --cluster=enterprise-eks-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT-ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Install with Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=enterprise-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

## 5. Deploy Monitoring Stack

### Prometheus & Grafana
```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.service.type=LoadBalancer
```

### CloudWatch Container Insights
```bash
# Deploy Container Insights
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed 's/{{cluster_name}}/enterprise-eks-cluster/;s/{{region_name}}/us-east-1/' | kubectl apply -f -
```

## 6. Common Pod Deployment Patterns

### Stateless Application
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 5
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: your-app:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

### Stateful Application with Persistent Storage
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  serviceName: database
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_PASSWORD
          value: "password"
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: gp3
      resources:
        requests:
          storage: 10Gi
```

## 7. Useful Commands

```bash
# Check cluster info
kubectl cluster-info
kubectl get nodes -o wide

# Monitor pods
kubectl get pods --all-namespaces
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Scale deployments
kubectl scale deployment nginx --replicas=5

# Port forwarding for testing
kubectl port-forward service/nginx 8080:80

# Get service endpoints
kubectl get services
kubectl get ingress

# Check resource usage
kubectl top nodes
kubectl top pods

# Debug networking
kubectl exec -it <pod-name> -- /bin/bash
```

## 8. Troubleshooting

### Pod Stuck in Pending
```bash
# Check node resources
kubectl describe nodes

# Check pod events
kubectl describe pod <pod-name>

# Check if nodes are ready
kubectl get nodes
```

### Service Not Accessible
```bash
# Check service endpoints
kubectl get endpoints

# Check security groups
aws ec2 describe-security-groups --group-ids <sg-id>

# Check load balancer
kubectl describe service <service-name>
```

### Storage Issues
```bash
# Check storage classes
kubectl get storageclass

# Check persistent volumes
kubectl get pv
kubectl get pvc

# Check EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi
```

## 9. Best Practices

1. **Resource Limits**: Always set resource requests and limits
2. **Health Checks**: Configure liveness and readiness probes
3. **Security**: Use service accounts and RBAC
4. **Monitoring**: Deploy logging and monitoring solutions
5. **Scaling**: Configure HPA for automatic scaling
6. **Storage**: Use appropriate storage classes for workloads