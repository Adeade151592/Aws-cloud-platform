# AWS Cloud Platform

Enterprise-grade AWS infrastructure with EKS, monitoring, logging, and GitOps.

## Status

![Terraform Validation](https://github.com/Adeade151592/Aws-cloud-platform/workflows/Terraform%20Validation/badge.svg)
![Kubernetes Validation](https://github.com/Adeade151592/Aws-cloud-platform/workflows/Kubernetes%20Validation/badge.svg)
![Security Scan](https://github.com/Adeade151592/Aws-cloud-platform/workflows/Security%20Scan/badge.svg)

## Architecture

- **Compute**: Amazon EKS 1.28
- **Networking**: Multi-AZ VPC with private/public subnets
- **Monitoring**: Prometheus + Grafana
- **Logging**: Fluent Bit → CloudWatch
- **GitOps**: ArgoCD
- **Secrets**: External Secrets Operator + AWS Secrets Manager

## Quick Start

### Prerequisites

- AWS CLI configured
- Terraform >= 1.5.0
- kubectl >= 1.28
- Helm >= 3.0
- Go >= 1.21 (for testing)

### Deploy

```bash
# Set environment variables
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION="eu-west-1"
export GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32)

# Deploy backend
cd terraform/backend
terraform init && terraform apply

# Deploy dev environment
cd ../environments/dev
terraform init && terraform apply

# Configure kubectl
aws eks update-kubeconfig --region eu-west-1 --name dev-eks-cluster

# Deploy Kubernetes resources
kubectl apply -f ../../kubernetes/base/

# Deploy applications (see DEPLOYMENT.md)
```

## CI/CD Workflows

### Validation Workflows
- **Terraform Validation**: Runs on every push to terraform/
- **Kubernetes Validation**: Runs on every push to kubernetes/
- **Security Scan**: Runs daily and on every PR

### Deployment Workflows
- **Deploy to Dev**: Automatic on main branch
- **Integration Tests**: Runs after successful deployment

## Security

- All containers run as non-root
- Pod Security Standards enforced
- Network policies with default deny
- Secrets managed via External Secrets Operator
- Regular security scans via GitHub Actions

See [SECURITY.md](SECURITY.md) for details.

## Documentation

- [Architecture](docs/architecture.md)
- [Security Guidelines](SECURITY.md)
- [Deployment Guide](DEPLOYMENT.md)
- [Disaster Recovery](docs/disaster-recovery.md)
- [Onboarding](docs/onboarding.md)
- [Runbooks](docs/runbooks.md)

## Testing

### Run Terratest Before Push

```bash
cd test
make init
make test-fast  # Validation only (no AWS resources)
make test       # Full integration tests (creates AWS resources)
```

See [test/README.md](test/README.md) for details.

## Contributing

1. Create feature branch
2. Make changes
3. Run tests: `cd test && make test-fast`
4. Run pre-commit hooks: `pre-commit run --all-files`
5. Create PR (requires 2 approvals)
6. CI/CD validates changes
7. Merge after approval

## Support

- Slack: #platform-engineering
- Email: platform-team@company.com
- On-call: Check PagerDuty rotation

## License

Internal use only - Company Confidential