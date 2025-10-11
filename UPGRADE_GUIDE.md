# EKS Cluster Upgrade Guide

## Overview
This guide covers upgrading EKS cluster components including Kubernetes version, node groups, add-ons, and other features.

## Pre-Upgrade Checklist

- [ ] Backup critical workloads and data
- [ ] Review [Kubernetes version skew policy](https://kubernetes.io/releases/version-skew-policy/)
- [ ] Test upgrades in non-production environment
- [ ] Check add-on compatibility with new Kubernetes version
- [ ] Plan maintenance window for minimal disruption

## 1. Kubernetes Version Upgrade

### Check Current Version
```bash
kubectl version --short
aws eks describe-cluster --name <cluster-name> --query cluster.version
```

### Upgrade Process
1. **Update Terraform configuration**:
   ```hcl
   variable "kubernetes_version" {
     default = "1.29"  # Update from 1.28
   }
   ```

2. **Plan and apply**:
   ```bash
   terraform plan
   terraform apply
   ```

3. **Verify control plane upgrade**:
   ```bash
   aws eks describe-cluster --name <cluster-name> --query cluster.version
   ```

### Supported Upgrade Path
- Only upgrade one minor version at a time (1.28 → 1.29)
- Control plane must be upgraded before nodes
- Add-ons should be updated after control plane

## 2. Node Group Upgrades

### Check Node Versions
```bash
kubectl get nodes -o wide
```

### Upgrade Methods

#### Method 1: Terraform (Recommended)
```hcl
# In node-groups.tf, update launch template
resource "aws_launch_template" "eks_node_group" {
  # Terraform will automatically use latest AMI for new K8s version
  image_id = data.aws_ssm_parameter.eks_ami_release_version.value
}

# Force node group update
resource "aws_eks_node_group" "main" {
  # Add this to force replacement
  version = var.kubernetes_version
  
  update_config {
    max_unavailable_percentage = 25  # Adjust based on workload tolerance
  }
}
```

#### Method 2: AWS CLI
```bash
# Update node group
aws eks update-nodegroup-version \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name> \
  --kubernetes-version 1.29
```

### Rolling Update Process
1. New nodes are launched with updated version
2. Pods are drained from old nodes
3. Old nodes are terminated
4. Process repeats until all nodes updated

## 3. Add-on Upgrades

### Check Current Add-on Versions
```bash
aws eks describe-addon --cluster-name <cluster-name> --addon-name vpc-cni
aws eks describe-addon --cluster-name <cluster-name> --addon-name coredns
aws eks describe-addon --cluster-name <cluster-name> --addon-name kube-proxy
aws eks describe-addon --cluster-name <cluster-name> --addon-name aws-ebs-csi-driver
```

### Upgrade Add-ons with Terraform
Terraform automatically uses latest compatible versions:
```hcl
# In addons.tf - these data sources get latest versions
data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}
```

Apply updates:
```bash
terraform plan
terraform apply
```

### Manual Add-on Upgrade
```bash
# Get available versions
aws eks describe-addon-versions --addon-name vpc-cni --kubernetes-version 1.29

# Update add-on
aws eks update-addon \
  --cluster-name <cluster-name> \
  --addon-name vpc-cni \
  --addon-version <new-version> \
  --resolve-conflicts OVERWRITE
```

## 4. Cluster Autoscaler Upgrade

### Update Autoscaler Version
```hcl
# In autoscaler.tf
resource "kubernetes_deployment" "cluster_autoscaler" {
  spec {
    template {
      spec {
        container {
          # Update image version to match Kubernetes version
          image = "k8s.gcr.io/autoscaling/cluster-autoscaler:v1.29.0"
        }
      }
    }
  }
}
```

### Version Compatibility Matrix
| Kubernetes Version | Cluster Autoscaler Version |
|-------------------|----------------------------|
| 1.28.x | v1.28.x |
| 1.29.x | v1.29.x |
| 1.30.x | v1.30.x |

## 5. Instance Type Upgrades

### Update Node Instance Types
```hcl
# In variables.tf or terraform.tfvars
variable "node_instance_type" {
  default = "t3.large"  # Upgrade from t3.medium
}
```

### Scaling Configuration Updates
```hcl
# Adjust scaling parameters
variable "node_max_size" {
  default = 20  # Increase from 10
}

variable "node_desired_size" {
  default = 4   # Increase from 2
}
```

## 6. Storage Upgrades

### EBS Volume Size Increase
```hcl
# In node-groups.tf
resource "aws_launch_template" "eks_node_group" {
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 100  # Increase from 50GB
      volume_type = "gp3"
      iops        = 3000  # Add IOPS for gp3
      throughput  = 125   # Add throughput for gp3
    }
  }
}
```

## 7. Security Updates

### Update AMI (Automatic)
EKS-optimized AMIs are automatically updated when you upgrade Kubernetes version or update node groups.

### KMS Key Rotation
```bash
# Enable automatic key rotation
aws kms enable-key-rotation --key-id <key-id>
```

## 8. Monitoring Upgrades

### CloudWatch Container Insights
```bash
# Deploy Container Insights
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | kubectl apply -f -
```

### Prometheus & Grafana (Optional)
```bash
# Add Prometheus using Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack
```

## 9. Upgrade Validation

### Post-Upgrade Checks
```bash
# Verify cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Check add-on status
aws eks describe-addon --cluster-name <cluster-name> --addon-name vpc-cni

# Verify workload functionality
kubectl get deployments
kubectl get services
```

### Rollback Procedures
If issues occur:
1. **Terraform**: Use `terraform apply` with previous configuration
2. **Node Groups**: Launch new node group with previous version
3. **Add-ons**: Downgrade using AWS CLI or Terraform

## 10. Upgrade Schedule Recommendations

### Production Environment
- **Kubernetes**: Upgrade 2-3 months after release
- **Node Groups**: Monthly security updates
- **Add-ons**: Quarterly updates
- **Instance Types**: Annual review

### Development Environment
- **Kubernetes**: Upgrade 1 month after release
- **Node Groups**: Bi-weekly updates
- **Add-ons**: Monthly updates

## Troubleshooting Common Issues

### Node Join Failures
```bash
# Check node logs
kubectl describe node <node-name>
aws logs get-log-events --log-group-name /aws/eks/<cluster-name>/cluster
```

### Add-on Conflicts
```bash
# Resolve conflicts with OVERWRITE
aws eks update-addon --resolve-conflicts OVERWRITE
```

### Pod Scheduling Issues
```bash
# Check node capacity and taints
kubectl describe nodes
kubectl get pods -o wide
```

## Best Practices

1. **Test First**: Always test upgrades in development environment
2. **Gradual Rollout**: Use blue-green or canary deployment strategies
3. **Monitor Closely**: Watch metrics during and after upgrades
4. **Backup Strategy**: Ensure backups of critical data
5. **Documentation**: Keep upgrade logs and procedures documented
6. **Automation**: Use CI/CD pipelines for consistent upgrades