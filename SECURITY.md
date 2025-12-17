# Security Guidelines

## Overview
This document outlines the security measures implemented in the AWS Cloud Platform.

## Infrastructure Security

### EKS Cluster Security
- **Private API Endpoint**: EKS API server is not publicly accessible
- **Node Groups**: Run in private subnets only
- **Pod Security Standards**: Enforced at namespace level
- **Network Policies**: Default deny-all with explicit allow rules
- **IRSA**: IAM Roles for Service Accounts for fine-grained permissions

### Terraform State Security
- **Encryption**: State files encrypted with KMS
- **Versioning**: Enabled for state recovery
- **Locking**: DynamoDB table prevents concurrent modifications
- **Access Control**: S3 bucket blocks all public access

### Container Security
- **Non-root Users**: All containers run as non-root
- **Read-only Root Filesystem**: Where possible
- **Security Contexts**: Proper seccomp profiles and capabilities
- **Resource Limits**: CPU and memory limits enforced

## Secrets Management

### External Secrets Operator
- Integrates with AWS Secrets Manager
- Automatic secret rotation support
- Namespace isolation

### Grafana Credentials
- Admin password stored in Kubernetes secret
- Generated randomly, not hardcoded

## Network Security

### VPC Configuration
- **Private Subnets**: Workloads run in private subnets
- **NAT Gateways**: Multi-AZ for high availability
- **Flow Logs**: VPC traffic monitoring enabled

### Network Policies
- Default deny ingress in application namespaces
- Explicit allow rules for required communication
- DNS access allowed to kube-system namespace

## Monitoring and Logging

### CloudWatch Integration
- EKS control plane logs enabled
- VPC Flow Logs for network monitoring
- Application logs via Fluent Bit

### Prometheus Stack
- Secure configuration with proper RBAC
- Persistent storage for metrics
- Grafana with secure authentication

## Compliance

### Pod Security Standards
- **Restricted**: Applied to application namespaces
- **Baseline**: Applied to system namespaces
- **Privileged**: Not used

### Resource Management
- Priority classes for critical workloads
- Resource quotas per namespace
- Horizontal Pod Autoscaling configured

## Best Practices

1. **Least Privilege**: All IAM roles follow principle of least privilege
2. **Encryption**: Data encrypted at rest and in transit
3. **Monitoring**: Comprehensive logging and monitoring
4. **Updates**: Regular security updates for all components
5. **Backup**: State files versioned and backed up

## Security Checklist

- [ ] EKS API endpoint is private
- [ ] All containers run as non-root
- [ ] Network policies are enforced
- [ ] Secrets are not hardcoded
- [ ] Resource limits are set
- [ ] Monitoring is configured
- [ ] Backup strategy is in place
- [ ] Security updates are applied regularly