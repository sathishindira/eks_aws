# EKS Cluster Architecture & Component Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Region                           │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    VPC (10.0.0.0/16)                   ││
│  │                                                         ││
│  │  ┌──────────────────┐    ┌──────────────────┐          ││
│  │  │   Public Subnet  │    │   Public Subnet  │          ││
│  │  │   (10.0.0.0/24)  │    │   (10.0.1.0/24)  │          ││
│  │  │                  │    │                  │          ││
│  │  │  ┌─────────────┐ │    │ ┌─────────────┐  │          ││
│  │  │  │ NAT Gateway │ │    │ │ NAT Gateway │  │          ││
│  │  │  └─────────────┘ │    │ └─────────────┘  │          ││
│  │  └──────────────────┘    └──────────────────┘          ││
│  │           │                        │                   ││
│  │  ┌──────────────────┐    ┌──────────────────┐          ││
│  │  │  Private Subnet  │    │  Private Subnet  │          ││
│  │  │  (10.0.10.0/24)  │    │  (10.0.11.0/24)  │          ││
│  │  │                  │    │                  │          ││
│  │  │ ┌──────────────┐ │    │ ┌──────────────┐ │          ││
│  │  │ │ EKS Worker   │ │    │ │ EKS Worker   │ │          ││
│  │  │ │ Nodes        │ │    │ │ Nodes        │ │          ││
│  │  │ └──────────────┘ │    │ └──────────────┘ │          ││
│  │  └──────────────────┘    └──────────────────┘          ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                EKS Control Plane                       ││
│  │              (AWS Managed)                             ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Core Components Explained

### 1. VPC (Virtual Private Cloud)
**Purpose**: Isolated network environment for your EKS cluster
**Why Needed**: 
- Network isolation and security
- Control over IP addressing and routing
- Foundation for all AWS resources

**Configuration**:
- CIDR: 10.0.0.0/16 (65,536 IP addresses)
- DNS hostnames and resolution enabled
- Tagged for EKS cluster discovery

### 2. Subnets
**Public Subnets** (2 across AZs):
- **Purpose**: Host NAT gateways and load balancers
- **Why Needed**: Internet access for private resources
- **CIDR**: 10.0.0.0/24, 10.0.1.0/24

**Private Subnets** (2 across AZs):
- **Purpose**: Host EKS worker nodes
- **Why Needed**: Security - nodes don't need direct internet access
- **CIDR**: 10.0.10.0/24, 10.0.11.0/24

### 3. Internet Gateway & NAT Gateways
**Internet Gateway**:
- **Purpose**: Provides internet access to public subnets
- **Why Needed**: Download container images, communicate with EKS API

**NAT Gateways** (2 for high availability):
- **Purpose**: Allow private subnet resources to access internet
- **Why Needed**: Worker nodes need to pull images and communicate with AWS services

### 4. EKS Control Plane
**Purpose**: Managed Kubernetes API server, etcd, and controllers
**Why Needed**: 
- Kubernetes cluster management
- API endpoint for kubectl commands
- Scheduling and orchestration

**Features**:
- Multi-AZ deployment for high availability
- Automatic updates and patching
- Integrated with AWS services

### 5. EKS Node Groups
**Purpose**: Managed EC2 instances running Kubernetes worker nodes
**Why Needed**:
- Run your application pods
- Provide compute resources for workloads
- Automatically join the EKS cluster

**Configuration**:
- Instance Type: t3.medium (2 vCPU, 4GB RAM)
- Autoscaling: 1-10 nodes
- EBS storage: 50GB per node

### 6. Security Groups
**Cluster Security Group**:
- Controls access to EKS API server
- Allows HTTPS (443) from workstation CIDR

**Node Security Group**:
- Allows communication between nodes
- Permits cluster control plane communication

### 7. IAM Roles & Policies
**EKS Cluster Role**:
- **Purpose**: Allows EKS to manage AWS resources
- **Policies**: AmazonEKSClusterPolicy

**Node Group Role**:
- **Purpose**: Allows worker nodes to join cluster and access AWS services
- **Policies**: 
  - AmazonEKSWorkerNodePolicy
  - AmazonEKS_CNI_Policy
  - AmazonEC2ContainerRegistryReadOnly

**IRSA (IAM Roles for Service Accounts)**:
- **Purpose**: Fine-grained permissions for Kubernetes pods
- **Why Needed**: Secure access to AWS services from pods

### 8. EKS Add-ons
**VPC CNI**:
- **Purpose**: Kubernetes networking using AWS VPC
- **Why Needed**: Pod-to-pod communication and IP management

**CoreDNS**:
- **Purpose**: DNS resolution within the cluster
- **Why Needed**: Service discovery and name resolution

**kube-proxy**:
- **Purpose**: Network proxy for Kubernetes services
- **Why Needed**: Load balancing and service routing

**EBS CSI Driver**:
- **Purpose**: Persistent storage for pods
- **Why Needed**: Stateful applications requiring persistent volumes

### 9. Cluster Autoscaler
**Purpose**: Automatically adjusts the number of nodes based on pod demands
**Why Needed**:
- Cost optimization - scale down when not needed
- Performance - scale up during high demand
- Automation - no manual intervention required

### 10. Encryption & Security
**KMS Key**:
- **Purpose**: Encrypt Kubernetes secrets at rest
- **Why Needed**: Data protection and compliance

**CloudWatch Logging**:
- **Purpose**: Monitor and troubleshoot cluster operations
- **Why Needed**: Observability and debugging

## Data Flow

1. **Pod Creation**: Developer creates pod via kubectl
2. **API Request**: kubectl sends request to EKS control plane
3. **Scheduling**: Control plane schedules pod on available node
4. **Image Pull**: Node pulls container image from registry via NAT gateway
5. **Pod Startup**: Container starts and gets VPC IP via CNI
6. **Service Access**: Pod communicates with other services via kube-proxy

## High Availability Design

- **Multi-AZ**: Resources distributed across 2 availability zones
- **Redundant NAT**: Separate NAT gateway per AZ
- **Auto Scaling**: Nodes automatically replace failed instances
- **Managed Control Plane**: AWS handles control plane availability

## Security Layers

1. **Network**: VPC isolation, security groups, private subnets
2. **Identity**: IAM roles with least privilege access
3. **Encryption**: KMS encryption for secrets
4. **Monitoring**: CloudWatch logs for audit trail
5. **Access Control**: Kubernetes RBAC (configured separately)