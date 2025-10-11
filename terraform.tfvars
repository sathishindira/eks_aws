# AWS Configuration
aws_region = "us-east-1"

# Cluster Configuration
cluster_name       = "enterprise-eks-cluster"
kubernetes_version = "1.32"
environment        = "production"

# Network Configuration
vpc_cidr         = "10.0.0.0/16"
workstation_cidr = "0.0.0.0/0"  # Restrict this to your IP range for security

# Node Group Configuration
node_instance_type  = "t3.medium"
node_desired_size   = 2
node_max_size       = 10
node_min_size       = 1
node_disk_size      = 50

# Tags
tags = {
  Terraform   = "true"
  Environment = "production"
  Project     = "enterprise-eks"
  Owner       = "devops-team"
}