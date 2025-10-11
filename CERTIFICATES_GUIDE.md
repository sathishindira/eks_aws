# EKS Certificates and Authentication Guide

## Overview
This guide explains how certificates are created and managed in EKS, and the role of userdata.sh and kubeconfig.tpl files.

## Certificate Authority (CA) in EKS

### Who Creates the Certificates?

**AWS EKS Service** automatically creates and manages all certificates:

1. **Cluster CA Certificate**: Created by AWS when EKS cluster is provisioned
2. **API Server Certificate**: Signed by cluster CA, managed by AWS
3. **Node Certificates**: Auto-generated when nodes join cluster
4. **Service Account Tokens**: JWT tokens signed by cluster CA

### Certificate Hierarchy

```
Root CA (AWS Managed)
├── EKS Cluster CA Certificate
    ├── API Server Certificate (HTTPS endpoint)
    ├── Node Kubelet Certificates (worker nodes)
    ├── Service Account Signing Key
    └── OIDC Provider Certificate (for IRSA)
```

## userdata.sh Explained

### Purpose
Bootstrap script that runs when EC2 instances (worker nodes) start up to join the EKS cluster.

### Current Script Breakdown
```bash
#!/bin/bash
set -o xtrace                    # Enable debug tracing
/etc/eks/bootstrap.sh ${cluster_name} --container-runtime ${container_runtime}
/opt/aws/bin/cfn-signal --exit-code $? --stack --resource NodeGroup --region ${AWS::Region}
```

### What `/etc/eks/bootstrap.sh` Does
1. **Downloads cluster CA certificate** from EKS API
2. **Configures kubelet** with cluster endpoint and CA
3. **Generates node certificates** using AWS IAM authenticator
4. **Joins node to cluster** using bootstrap token
5. **Starts container runtime** (containerd)
6. **Configures CNI networking**

### Enhanced userdata.sh Example
```bash
#!/bin/bash
set -o xtrace

# Set cluster name and region
CLUSTER_NAME="${cluster_name}"
REGION="${aws_region}"

# Bootstrap node to join EKS cluster
/etc/eks/bootstrap.sh $CLUSTER_NAME \
  --container-runtime ${container_runtime} \
  --kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=normal'

# Install additional tools (optional)
yum update -y
yum install -y amazon-cloudwatch-agent

# Signal CloudFormation (if using CF)
/opt/aws/bin/cfn-signal --exit-code $? \
  --stack ${stack_name} \
  --resource NodeGroup \
  --region $REGION
```

## kubeconfig.tpl Explained

### Purpose
Template for generating kubectl configuration file to connect to EKS cluster.

### Template Breakdown
```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${cluster_ca}  # Base64 encoded CA cert
    server: ${cluster_endpoint}                # EKS API server URL
  name: ${cluster_name}
contexts:
- context:
    cluster: ${cluster_name}
    user: ${cluster_name}
  name: ${cluster_name}
current-context: ${cluster_name}
kind: Config
preferences: {}
users:
- name: ${cluster_name}
  user:
    exec:                                      # Use AWS CLI for authentication
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws                             # AWS CLI command
      args:
        - --region
        - ${aws_region}
        - eks
        - get-token                            # Get temporary token
        - --cluster-name
        - ${cluster_name}
```

### How Authentication Works
1. **kubectl** reads kubeconfig file
2. **Executes** `aws eks get-token` command
3. **AWS CLI** uses IAM credentials to get temporary token
4. **Token** is sent to EKS API server
5. **EKS** validates token against IAM
6. **Access granted** based on IAM permissions and Kubernetes RBAC

## Certificate Creation Process

### 1. Cluster Creation
```
AWS EKS Service:
├── Generates Root CA private key
├── Creates Cluster CA certificate
├── Signs API server certificate
└── Configures OIDC provider
```

### 2. Node Registration
```
Worker Node Startup:
├── userdata.sh executes
├── bootstrap.sh downloads cluster CA
├── Node generates CSR (Certificate Signing Request)
├── EKS auto-approves and signs node certificate
└── Kubelet starts with valid certificates
```

### 3. Pod Authentication
```
Service Account Token:
├── Kubernetes creates JWT token
├── Token signed by cluster CA
├── Pod mounts token as volume
└── Used for API server communication
```

## Certificate Locations

### On Worker Nodes
```
/etc/kubernetes/
├── kubelet/
│   ├── kubelet-config.json     # Kubelet configuration
│   └── kubelet.kubeconfig      # Node's kubeconfig
├── pki/
│   ├── ca.crt                  # Cluster CA certificate
│   └── kubelet-client.crt      # Node client certificate
└── manifests/                  # Static pod manifests
```

### In Terraform Outputs
```hcl
output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}
```

## IRSA (IAM Roles for Service Accounts)

### Certificate Chain for IRSA
```
AWS Root CA
├── EKS OIDC Provider Certificate
    └── Service Account JWT Token
        └── Pod assumes IAM role
```

### How IRSA Works
1. **EKS** creates OIDC identity provider
2. **Service Account** gets annotated with IAM role ARN
3. **Pod** receives JWT token signed by OIDC provider
4. **AWS STS** exchanges JWT for temporary AWS credentials
5. **Pod** uses AWS credentials to access AWS services

## Security Considerations

### Certificate Rotation
- **Cluster CA**: Managed by AWS, rotated automatically
- **Node certificates**: Auto-renewed by kubelet
- **Service account tokens**: Rotated every 12 hours by default

### Best Practices
1. **Never expose** private keys or certificates in logs
2. **Use IRSA** instead of storing AWS credentials in pods
3. **Rotate** kubeconfig tokens regularly
4. **Monitor** certificate expiration dates
5. **Restrict** API server access with security groups

## Troubleshooting Certificate Issues

### Common Problems
```bash
# Check node certificate status
kubectl get csr

# View kubelet logs
journalctl -u kubelet -f

# Check API server connectivity
kubectl cluster-info

# Verify certificate authority
openssl x509 -in /etc/kubernetes/pki/ca.crt -text -noout
```

### Certificate Validation
```bash
# Test cluster CA certificate
echo "${cluster_ca}" | base64 -d | openssl x509 -text -noout

# Verify API server certificate
openssl s_client -connect ${cluster_endpoint}:443 -servername ${cluster_endpoint}
```

## Integration with Terraform

### How Terraform Gets Certificates
```hcl
# EKS automatically generates and provides CA certificate
resource "aws_eks_cluster" "main" {
  # ... configuration
}

# Terraform reads the certificate from EKS API
data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.main.name
}

# Certificate available in outputs
output "cluster_ca" {
  value = data.aws_eks_cluster.cluster.certificate_authority[0].data
}
```

This certificate infrastructure ensures secure communication between all cluster components without manual certificate management.