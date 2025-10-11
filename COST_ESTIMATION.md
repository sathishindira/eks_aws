# EKS Cluster Cost Estimation

## Cost Breakdown (US-West-2 Region)

### Core Components

| Component | Hourly Cost | Daily Cost | Description |
|-----------|-------------|------------|-------------|
| **EKS Control Plane** | $0.10 | $2.40 | Managed Kubernetes control plane |
| **EC2 Instances (2x t3.medium)** | $0.0832 | $1.997 | Worker nodes (2 × $0.0416/hour) |
| **EBS Storage (100GB gp3)** | $0.0008 | $0.019 | Node storage (2 × 50GB) |
| **NAT Gateway (2x)** | $0.09 | $2.16 | Internet access for private subnets |
| **Elastic IPs (2x)** | $0.005 | $0.12 | Static IPs for NAT gateways |
| **CloudWatch Logs** | ~$0.001 | ~$0.024 | Control plane logging |
| **KMS Key** | $0.003 | $0.072 | Encryption key usage |

### **Total Estimated Cost**
- **1 Hour**: ~$0.28
- **1 Day**: ~$6.83
- **1 Month**: ~$205

### Data Transfer Costs (Additional)
- **NAT Gateway Data**: $0.045/GB processed
- **Cross-AZ Data**: $0.01/GB between availability zones
- **Internet Egress**: $0.09/GB (first 1GB free monthly)

## Cost Optimization Strategies

### Immediate Savings
1. **Use Spot Instances**: Save up to 70% on EC2 costs
2. **Right-size Instances**: Start with t3.small if workload permits
3. **Single NAT Gateway**: Use one NAT gateway for dev environments
4. **Reduce Log Retention**: Set CloudWatch logs to 1-3 days

### Long-term Savings
1. **Reserved Instances**: 30-60% savings with 1-3 year commitments
2. **Savings Plans**: Flexible compute savings
3. **Cluster Autoscaler**: Automatically scale down during low usage
4. **Fargate**: Consider for specific workloads to eliminate node management

## Cost Monitoring
- Enable AWS Cost Explorer
- Set up billing alerts
- Use AWS Cost and Usage Reports
- Monitor with CloudWatch metrics

## Regional Cost Variations
Costs may vary by region:
- **US-East-1**: ~5% lower
- **EU-West-1**: ~10% higher
- **AP-Southeast-1**: ~15% higher

*Note: Prices are estimates based on AWS pricing as of 2024 and may vary. Use AWS Pricing Calculator for precise estimates.*