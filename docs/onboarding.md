# Platform Onboarding Guide

## Welcome to the Cloud Platform Team

This guide will help you get up to speed with our AWS cloud platform infrastructure.

## Prerequisites

### Required Tools
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Install Terraform
brew install terraform

# Install kubectl
brew install kubectl

# Install Helm
brew install helm

# Install k9s (optional but recommended)
brew install k9s

# Install ArgoCD CLI
brew install argocd
```

### AWS Access
1. Request AWS IAM user from platform team lead
2. Configure MFA (mandatory)
3. Configure AWS CLI:
```bash
aws configure
# Enter your access key, secret key, region (eu-west-1), output format (json)
```

### GitHub Access
1. Request access to `cloud-platform` and `cloud-platform-apps` repositories
2. Set up SSH keys for Git

## Project Structure

```
cloud-platform/
├── terraform/          # Infrastructure as Code
│   ├── backend/        # S3 + DynamoDB for state
│   ├── networking/     # VPC, subnets, routing
│   ├── iam/            # IAM roles and policies
│   ├── eks/            # EKS cluster config
│   └── environments/   # Dev/staging configs
├── kubernetes/         # Kubernetes manifests
│   ├── base/           # Namespaces, policies, quotas
│   ├── monitoring/     # Prometheus, Grafana, autoscaler
│   ├── logging/        # FluentBit for CloudWatch
│   └── applications/   # ArgoCD configurations
└── docs/              # Documentation
```

## Your First Week

### Day 1: Environment Setup
- [ ] Install all required tools
- [ ] Configure AWS CLI and test access: `aws sts get-caller-identity`
- [ ] Clone repository: `git clone git@github.com:your-org/cloud-platform.git`
- [ ] Read `architecture.md` and `security.md`

### Day 2: Explore Infrastructure
- [ ] Review Terraform modules in `terraform/` directory
- [ ] Understand networking setup: `terraform/networking/main.tf`
- [ ] Review IAM roles and IRSA configuration: `terraform/iam/main.tf`

### Day 3: Connect to Cluster
```bash
# Configure kubectl for dev cluster
aws eks update-kubeconfig --region eu-west-1 --name dev-eks-cluster

# Verify connection
kubectl get nodes
kubectl get pods --all-namespaces

# Explore with k9s (optional)
k9s
```

### Day 4: Deploy a Test Application
```bash
# Create a simple deployment
kubectl create namespace test
kubectl run nginx --image=nginx --namespace=test
kubectl expose pod nginx --port=80 --namespace=test
kubectl get all -n test

# Clean up
kubectl delete namespace test
```

### Day 5: Review GitOps Flow
- [ ] Access ArgoCD UI (get URL from platform team)
- [ ] Review example Application manifests: `kubernetes/applications/argocd-apps.yaml`
- [ ] Understand sync policies and automated vs. manual deployment

## Common Tasks

### Deploying Infrastructure Changes

```bash
cd terraform/networking
terraform init
terraform plan
terraform apply  # Only after peer review!
```

### Accessing Grafana Dashboard
```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Access at http://localhost:3000
# Default credentials: admin / prom-operator (check with team)
```

### Viewing Logs
```bash
# Kubernetes logs
kubectl logs -f <pod-name> -n <namespace>

# CloudWatch logs (via AWS Console or CLI)
aws logs tail /aws/eks/cloud-platform/application-logs --follow
```

### Debugging Pod Issues
```bash
# Describe pod for events
kubectl describe pod <pod-name> -n <namespace>

# Check resource usage
kubectl top pods -n <namespace>

# Execute into pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
```

## Team Workflow

### Infrastructure Changes
1. Create feature branch: `git checkout -b feature/your-change`
2. Make Terraform changes
3. Run `terraform fmt` and `terraform validate`
4. Create PR with clear description
5. Request review from 2 team members
6. Apply after approval (lead engineer only)

### Application Deployments
1. Application teams commit changes to `cloud-platform-apps` repo
2. ArgoCD detects changes and syncs automatically
3. Monitor deployment in ArgoCD UI
4. Rollback via Git revert if issues arise

### Incident Response
1. Alert fires in Prometheus/Grafana or PagerDuty
2. Check `docs/runbooks.md` for specific playbook
3. Join incident channel: `#incidents-platform`
4. Follow runbook steps
5. Document actions and outcomes
6. Conduct post-mortem within 48 hours

## Learning Resources

### Internal
- [ ] `docs/architecture.md` - Platform architecture and design decisions
- [ ] `docs/security.md` - Security controls and compliance
- [ ] `docs/runbooks.md` - Operational procedures

### External
- **Terraform**: [HashiCorp Learn](https://learn.hashicorp.com/terraform)
- **EKS**: [AWS EKS Workshop](https://www.eksworkshop.com/)
- **Kubernetes**: [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- **GitOps**: [Argo CD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- **Prometheus**: [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)

## Getting Help

- **Platform Team Slack**: `#platform-engineering`
- **Documentation**: This `docs/` directory
- **Office Hours**: Tuesday/Thursday 3-4 PM (Book via Google Calendar)
- **On-call Engineer**: Check PagerDuty rotation

## Security Reminders

⚠️ **Never**:
- Commit secrets to Git
- Share AWS credentials
- Modify production without approval
- Disable security controls without security team review

✅ **Always**:
- Use MFA for AWS access
- Follow least-privilege principle
- Document changes in PR descriptions
- Run `terraform plan` before `apply`
- Test in dev before staging/prod

## Feedback

This is a living document. If you found something confusing or missing during onboarding, please submit a PR to improve it for the next person!

Welcome to the team! 🚀
