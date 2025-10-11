# Enterprise EKS Cluster Terraform Configuration

This Terraform configuration creates a production-ready Amazon EKS cluster with autoscaling capabilities for enterprise use.

## Architecture

- **VPC**: Custom VPC with public and private subnets across 2 AZs
- **EKS Cluster**: Managed Kubernetes control plane with encryption
- **Node Groups**: Managed node groups with autoscaling (1-10 nodes)
- **Add-ons**: VPC CNI, CoreDNS, kube-proxy, EBS CSI driver
- **Security**: KMS encryption, security groups, IAM roles with least privilege
- **Monitoring**: CloudWatch logging enabled

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0 installed
3. kubectl installed

## Required AWS Permissions

Your AWS user/role needs permissions for:
- EKS cluster management
- EC2 instances and networking
- IAM role creation
- KMS key management
- CloudWatch logs

## Deployment

1. **Clone and navigate to the directory:**
   ```bash
   cd terraform
   ```

2. **Copy and customize variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Plan the deployment:**
   ```bash
   terraform plan
   ```

5. **Apply the configuration:**
   ```bash
   terraform apply
   ```

6. **Configure kubectl:**
   ```bash
   aws eks update-kubeconfig --region <your-region> --name <cluster-name>
   ```

## Configuration Options

### Key Variables

- `cluster_name`: Name of your EKS cluster
- `kubernetes_version`: Kubernetes version (default: 1.28)
- `node_instance_type`: EC2 instance type for nodes (default: t3.medium)
- `node_min_size`: Minimum nodes (default: 1)
- `node_max_size`: Maximum nodes (default: 10)
- `node_desired_size`: Desired nodes (default: 2)
- `workstation_cidr`: IP range for cluster access (restrict for security)

### Autoscaling

The cluster includes:
- **Cluster Autoscaler**: Automatically scales nodes based on pod demands
- **Node Group Autoscaling**: Configured with min/max/desired capacity
- **Launch Template**: Optimized for EKS workloads

## Security Features

- **Encryption at Rest**: EKS secrets encrypted with KMS
- **Network Security**: Private subnets for nodes, security groups
- **IAM Roles**: Least privilege access with IRSA support
- **Logging**: Control plane logs to CloudWatch

## Outputs

After deployment, you'll get:
- Cluster endpoint and certificate
- VPC and subnet IDs
- Security group IDs
- IAM role ARNs
- kubectl configuration

## Cleanup

To destroy the infrastructure:
```bash
terraform destroy
```

## Cost Optimization

- Uses t3.medium instances (adjust based on workload)
- Autoscaling prevents over-provisioning
- Spot instances can be enabled for cost savings
- Monitor CloudWatch costs

## Troubleshooting

1. **Node group creation fails**: Check IAM permissions and subnet configuration
2. **Pods can't schedule**: Verify node group scaling and taints
3. **Network issues**: Check security groups and VPC configuration
4. **Authentication issues**: Ensure AWS CLI is configured correctly

## Additional Documentation

- **[Cost Estimation](COST_ESTIMATION.md)**: Detailed cost breakdown and optimization strategies
- **[Architecture Guide](ARCHITECTURE_GUIDE.md)**: Component explanations and design decisions
- **[Upgrade Guide](UPGRADE_GUIDE.md)**: Step-by-step upgrade procedures for all components

## Production Considerations

- Restrict `workstation_cidr` to your organization's IP ranges
- Enable additional monitoring and alerting
- Implement backup strategies for persistent volumes
- Consider multi-region deployment for high availability
- Review and adjust resource limits based on workload requirements