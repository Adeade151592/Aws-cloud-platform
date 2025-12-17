# Cloud Platform Architecture

## Overview

This document describes the architecture of a production-ready AWS cloud platform designed to support containerized workloads in a secure, scalable, and compliant environment.

## Design Principles

1. **Security First**: Defense in depth with network policies, pod security standards, and IRSA
2. **High Availability**: Multi-AZ deployment for all critical components
3. **Infrastructure as Code**: 100% codified using Terraform
4. **GitOps**: Declarative application delivery using ArgoCD
5. **Observability**: Comprehensive monitoring, logging, and alerting from day one

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Account                          │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                  VPC (10.0.0.0/16)                      │ │
│  │                                                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │  AZ-1        │  │  AZ-2        │  │  AZ-3        │ │ │
│  │  │              │  │              │  │              │ │ │
│  │  │  Public      │  │  Public      │  │  Public      │ │ │
│  │  │  Subnet      │  │  Subnet      │  │  Subnet      │ │ │
│  │  │  NAT GW      │  │  NAT GW      │  │  NAT GW      │ │ │
│  │  │              │  │              │  │              │ │ │
│  │  │  Private     │  │  Private     │  │  Private     │ │ │
│  │  │  Subnet      │  │  Subnet      │  │  Subnet      │ │ │
│  │  │  EKS Nodes   │  │  EKS Nodes   │  │  EKS Nodes   │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │ │
│  │                                                          │ │
│  │  EKS Control Plane (Managed by AWS)                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  Supporting Services:                                         │
│  - S3 (Terraform State)                                      │
│  - DynamoDB (State Locking)                                  │
│  - Secrets Manager (Application Secrets)                     │
│  - CloudWatch (Logging & Metrics)                            │
└─────────────────────────────────────────────────────────────┘
```

## Component Architecture

### 1. Network Layer

**Design**: Multi-AZ VPC with public and private subnets

**Key Decisions**:
- **3 Availability Zones**: Balance between cost and resilience (2 AZs = minimum, 3 AZs = production standard)
- **NAT Gateway per AZ**: High availability for egress traffic, prevents single point of failure
- **CIDR Planning**: `/16` VPC with `/20` subnets provides ~4000 IPs per subnet, room for growth
- **VPC Flow Logs**: Network monitoring and security forensics

**Trade-offs**:
- ✅ **Pro**: True HA with zone-level isolation
- ❌ **Con**: Higher cost (3 NAT Gateways ~$100/month)
- 💡 **At Scale**: Consider VPC endpoints for AWS services to reduce data transfer costs

### 2. EKS Control Plane

**Design**: Managed Kubernetes with both public and private access

**Key Decisions**:
- **Version 1.28**: Recent stable version with extended support
- **Private Endpoint**: Node-to-control plane traffic stays within VPC
- **Public Endpoint**: Restricted by CIDR (configurable), required for initial bootstrap and CI/CD
- **Control Plane Logging**: All log types enabled for audit compliance

**Trade-offs**:
- ✅ **Pro**: AWS manages upgrades, patches, and HA
- ❌ **Con**: Less control over control plane configuration
- 💡 **At Scale**: Move to fully private endpoints with VPN/Direct Connect access

### 3. Compute Layer (EKS Nodes)

**Design**: Managed node groups in private subnets

**Key Decisions**:
- **Managed Node Groups**: AWS handles ASG, AMI updates, and cordoning
- **Private Subnets Only**: Workers never get public IPs
- **T3.medium**: Cost-optimized for general workloads (2 vCPU, 4GB RAM)
- **Auto-scaling Tags**: Enables cluster autoscaler integration

**Trade-offs**:
- ✅ **Pro**: Simplified operations, automatic AMI patching
- ❌ **Con**: Less flexibility than self-managed nodes
- 💡 **At Scale**: Add spot instances for non-critical workloads, GPU node groups for ML

### 4. IAM & Security

**Design**: Least-privilege IRSA (IAM Roles for Service Accounts)

**Key Decisions**:
- **OIDC Provider**: Enables workload identity federation
- **Separate IAM Roles**: Per-service granular permissions (cluster-autoscaler, external-secrets, etc.)
- **No Node-Level Permissions**: All AWS access via IRSA, not instance profiles

**Trade-offs**:
- ✅ **Pro**: Pod-level AWS permissions, no shared credentials
- ✅ **Pro**: Supports audit trail per workload
- ❌ **Con**: More complex setup vs. node-level permissions
- 💡 **At Scale**: Integrate with AWS Organizations SCPs for guardrails

### 5. Observability Stack

**Design**: Prometheus + Grafana for metrics, FluentBit + CloudWatch for logs

**Key Decisions**:
- **Kube-Prometheus-Stack**: Industry standard, includes AlertManager and pre-built dashboards
- **FluentBit**: Lightweight log shipper (vs Fluentd)
- **CloudWatch Logs**: Centralized, integrated with AWS security tools (GuardDuty, Security Hub)
- **15-day Retention**: Balance between cost and troubleshooting needs

**Trade-offs**:
- ✅ **Pro**: Proven stack, extensive community support
- ❌ **Con**: Storage costs scale with cluster size
- 💡 **At Scale**: Consider Loki for logs, Thanos for long-term Prometheus storage, or move to managed Grafana/Prometheus

### 6. GitOps & Delivery

**Design**: ArgoCD for declarative application deployment

**Key Decisions**:
- **Separate Repo Strategy**: Infrastructure repo vs. application repo separation
- **Environment Isolation**: Dev/staging/prod represented as ArgoCD projects
- **Automated Sync**: Self-healing enabled for platform services

**Trade-offs**:
- ✅ **Pro**: Git as source of truth, auditability, easy rollbacks
- ❌ **Con**: Learning curve for teams new to GitOps
- 💡 **At Scale**: Add ApplicationSets for multi-cluster management

## Security Architecture

### Defense in Depth

1. **Network Layer**: VPC isolation, security groups, NACLs
2. **Kubernetes Layer**: Network policies, pod security standards
3. **Application Layer**: IRSA, secrets management, RBAC
4. **Audit Layer**: CloudTrail, EKS control plane logs, VPC flow logs

### Compliance Considerations

This architecture supports:
- **CIS Kubernetes Benchmark**: Pod security standards enforced
- **PCI-DSS**: Network segmentation, encryption at rest/transit
- **SOC 2**: Audit logging, access controls, change management via GitOps
- **GDPR**: Data residency controls via region selection

## Disaster Recovery

**RPO (Recovery Point Objective)**: < 1 hour
- Terraform state versioned in S3
- GitOps repo as configuration backup
- EBS volume snapshots

**RTO (Recovery Time Objective)**: < 4 hours
- Infrastructure rebuild via Terraform
- Application redeploy via ArgoCD
- Prometheus/Grafana data loss acceptable (metrics, not transactional)

## Cost Optimization

**Current Estimated Monthly Cost (dev environment)**:
- EKS Control Plane: $73
- EC2 (3x t3.medium): ~$90
- NAT Gateways (3): ~$100
- Data Transfer: ~$50
- EBS Volumes: ~$20
- **Total**: ~$330/month

**Optimization Strategies**:
1. Use spot instances for non-critical workloads (60-90% savings)
2. Implement pod autoscaling (HPA) to reduce over-provisioning
3. Use VPC endpoints for S3/DynamoDB to reduce NAT costs
4. Leverage Savings Plans for production environments

## Scalability

**Current Capacity**: 
- 2-6 nodes (t3.medium) = 6-18 vCPU, 12-36GB RAM
- Supports ~30-90 pods (depending on resource requests)

**Scaling Mechanisms**:
1. **Cluster Autoscaler**: Adds/removes nodes based on pending pods
2. **HPA**: Scales pod replicas based on CPU/memory
3. **VPA**: Adjusts pod resource requests (future consideration)

**Growth Path**:
- Current setup scales to ~100 pods before needing architectural changes
- Next step: Multiple node groups (general, compute-intensive, memory-intensive)
- Beyond: Multi-cluster with shared control plane, service mesh for cross-cluster communication

## What Would Change at Evoke Scale

Based on understanding of regulated betting environments:

1. **Multi-Account Strategy**: Separate AWS accounts for dev/staging/prod using AWS Organizations
2. **Private Clusters**: Remove public endpoint access, use AWS PrivateLink
3. **Enhanced Monitoring**: APM tools (DataDog/New Relic), real-user monitoring
4. **WAF & DDoS Protection**: CloudFront + WAF in front of ALB ingress
5. **Database Layer**: RDS Multi-AZ with read replicas, ElastiCache for session state
6. **CI/CD Hardening**: Artifact scanning, policy-as-code gates, deployment windows
7. **Service Mesh**: Istio/Linkerd for traffic management and mTLS between services
8. **Backup & DR**: Cross-region replication, warm standby in secondary region

## References

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
