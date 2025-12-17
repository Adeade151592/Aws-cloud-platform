# Quick Start Guide

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **GitHub Secrets** configured:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `GRAFANA_PASSWORD`

## Step 1: Setup Backend (One-time)

The S3 backend must be created before deploying infrastructure.

### Option A: Via GitHub Actions (Recommended)

1. Go to your repository: `https://github.com/Adeade151592/Aws-cloud-platform`
2. Click **Actions** tab
3. Select **Setup Backend** workflow
4. Click **Run workflow** → **Run workflow**
5. Wait for completion (~2 minutes)

### Option B: Locally

```bash
cd terraform/backend
terraform init
terraform apply
```

## Step 2: Deploy Infrastructure

After backend is setup, deploy your environment:

### Via GitHub Actions

1. Go to **Actions** tab
2. Select **Deploy to Dev** workflow
3. Click **Run workflow** → **Run workflow**
4. Monitor deployment (~15-20 minutes)

### Locally

```bash
# Deploy dev environment
cd terraform/environments/dev
terraform init
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region eu-west-1 --name dev-eks-cluster

# Deploy Kubernetes resources
kubectl apply -f ../../kubernetes/base/
```

## Step 3: Verify Deployment

```bash
# Check cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Check services
kubectl get svc --all-namespaces
```

## Step 4: Access Services

### Grafana
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
# Access: http://localhost:3000
# User: admin
# Password: (from GRAFANA_PASSWORD secret)
```

### ArgoCD
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Access: https://localhost:8080
# User: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Troubleshooting

### Backend Access Denied

If you see "Access Denied" errors:
1. Ensure AWS credentials are configured
2. Run **Setup Backend** workflow first
3. Check IAM permissions for S3 and DynamoDB

### Terraform State Lock

If state is locked:
```bash
# List locks
aws dynamodb scan --table-name cloud-platform-terraform-locks

# Force unlock (use carefully)
terraform force-unlock <LOCK_ID>
```

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

## Cleanup

To destroy everything:

```bash
# Delete Kubernetes resources
kubectl delete -f kubernetes/base/

# Destroy infrastructure
cd terraform/environments/dev
terraform destroy

# Destroy backend (optional - will delete state!)
cd ../../backend
terraform destroy
```

## Next Steps

- Review [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment guide
- Check [SECURITY.md](SECURITY.md) for security best practices
- Read [docs/architecture.md](docs/architecture.md) for architecture overview
