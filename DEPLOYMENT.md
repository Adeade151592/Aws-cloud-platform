# Deployment Guide

## Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **Terraform** >= 1.5.0 installed
3. **kubectl** installed
4. **Helm** >= 3.0 installed

## Environment Variables

Set the following environment variables before deployment:

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION="eu-west-1"
export GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32)
```

## Deployment Steps

### 1. Deploy Backend Infrastructure

```bash
cd terraform/backend
terraform init
terraform plan -var="state_bucket_name=your-unique-bucket-name"
terraform apply -var="state_bucket_name=your-unique-bucket-name"
```

### 2. Deploy Environment (Dev/Staging)

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 3. Configure kubectl

```bash
aws eks update-kubeconfig --region eu-west-1 --name dev-eks-cluster
```

### 4. Deploy Base Kubernetes Resources

```bash
kubectl apply -f kubernetes/base/
```

### 5. Create Grafana Secret

```bash
kubectl create namespace monitoring
kubectl create secret generic grafana-admin-secret \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=$GRAFANA_ADMIN_PASSWORD \
  -n monitoring
```

### 6. Deploy Monitoring Stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f kubernetes/monitoring/prometheus-values.yaml
```

### 7. Deploy Logging

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Update fluent-bit-values.yaml with your AWS account ID
envsubst < kubernetes/logging/fluent-bit-values.yaml | \
helm install aws-for-fluent-bit eks/aws-for-fluent-bit \
  -n logging \
  -f -
```

### 8. Deploy External Secrets

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

kubectl create namespace external-secrets
envsubst < kubernetes/monitoring/external-secrets-values.yaml | \
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  -f -
```

### 9. Deploy ArgoCD

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

kubectl create namespace argocd
helm install argocd argo/argo-cd \
  -n argocd \
  -f kubernetes/applications/argocd-values.yaml
```

## Post-Deployment Verification

### Check Cluster Status
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

### Access Grafana
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
# Access at http://localhost:3000
# Username: admin
# Password: $GRAFANA_ADMIN_PASSWORD
```

### Access ArgoCD
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Access at https://localhost:8080
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Troubleshooting

### Common Issues

1. **IAM Permissions**: Ensure your AWS credentials have sufficient permissions
2. **Resource Limits**: Check if you've hit AWS service limits
3. **Network Connectivity**: Verify VPC and subnet configurations
4. **Pod Security**: Check if pods are failing due to security contexts

### Useful Commands

```bash
# Check EKS cluster status
aws eks describe-cluster --name dev-eks-cluster

# Check node group status
aws eks describe-nodegroup --cluster-name dev-eks-cluster --nodegroup-name dev-eks-cluster-node-group

# View pod logs
kubectl logs -n <namespace> <pod-name>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Cleanup

To destroy the infrastructure:

```bash
# Delete Helm releases
helm uninstall -n monitoring kube-prometheus
helm uninstall -n logging aws-for-fluent-bit
helm uninstall -n external-secrets external-secrets
helm uninstall -n argocd argocd

# Delete Kubernetes resources
kubectl delete -f kubernetes/base/

# Destroy Terraform infrastructure
cd terraform/environments/dev
terraform destroy

cd ../../backend
terraform destroy
```