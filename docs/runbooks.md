# Operational Runbooks

## Purpose

This document contains step-by-step procedures for common operational tasks and incident response.

## General Principles

- Follow the runbook exactly during incidents
- Document deviations and outcomes
- Update runbooks after incidents (lessons learned)
- Escalate if unsure—don't guess

---

## Runbook Index

1. [Node Group Scaling Issues](#1-node-group-scaling-issues)
2. [Pod CrashLoopBackOff](#2-pod-crashloopbackoff)
3. [High Memory Usage](#3-high-memory-usage)
4. [Certificate Expiration](#4-certificate-expiration)
5. [GitOps Sync Failure](#5-gitops-sync-failure)
6. [Control Plane API Latency](#6-control-plane-api-latency)
7. [Disaster Recovery](#7-disaster-recovery)

---

## 1. Node Group Scaling Issues

**Symptom**: Pods stuck in Pending state, cluster autoscaler not adding nodes

### Diagnostic Steps
```bash
# Check pending pods
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# Check cluster autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler --tail=100

# Check node group status
aws eks describe-nodegroup \
  --cluster-name dev-eks-cluster \
  --nodegroup-name dev-eks-cluster-node-group
```

### Common Causes
1. **IAM Permissions**: Cluster autoscaler role missing permissions
2. **ASG Limits**: Max size reached on auto-scaling group
3. **Resource Limits**: AWS account limits (EC2 instance limit, EIP limit)
4. **Subnet IP Exhaustion**: No available IPs in private subnets

### Resolution
```bash
# Check IAM role permissions
aws iam get-role --role-name cloud-platform-eks-cluster-autoscaler

# Increase ASG max size (if appropriate)
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name <asg-name> \
  --max-size 10

# Check EC2 limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A  # Running On-Demand instances
```

### Prevention
- Monitor ASG capacity via CloudWatch
- Set up alerts for ASG near max capacity
- Regularly review and request limit increases

---

## 2. Pod CrashLoopBackOff

**Symptom**: Pod repeatedly restarting, application unavailable

### Diagnostic Steps
```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# View logs from current container
kubectl logs <pod-name> -n <namespace>

# View logs from previous crash
kubectl logs <pod-name> -n <namespace> --previous

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Common Causes
1. **Application Error**: Bug in application code
2. **Missing Secrets/ConfigMaps**: Pod can't find required config
3. **Resource Limits**: OOMKilled (out of memory)
4. **Liveness Probe Failure**: Health check failing prematurely

### Resolution
```bash
# Check resource usage (if OOMKilled)
kubectl top pod <pod-name> -n <namespace>

# Verify secrets exist
kubectl get secrets -n <namespace>

# Temporarily increase resources (if OOMKilled)
kubectl edit deployment <deployment-name> -n <namespace>
# Increase memory limits, save and exit

# Check liveness probe settings
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 livenessProbe
```

### Escalation
- Application issues: Contact application team with logs
- Platform issues: Notify platform lead

---

## 3. High Memory Usage

**Symptom**: Nodes running out of memory, OOMKilled pods

### Diagnostic Steps
```bash
# Check node resource usage
kubectl top nodes

# Check pod resource usage by namespace
kubectl top pods --all-namespaces --sort-by=memory

# Describe node for pressure conditions
kubectl describe node <node-name> | grep -A 5 Conditions
```

### Immediate Actions
```bash
# Identify memory-hungry pods
kubectl top pods --all-namespaces --sort-by=memory | head -20

# Check for memory leaks (increasing over time)
# Port-forward to Grafana and review memory trends

# If critical, cordon node to prevent new pods
kubectl cordon <node-name>

# Drain node gracefully (if safe)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

### Resolution
```bash
# Review and adjust pod resource limits
kubectl edit deployment <deployment-name> -n <namespace>

# Enforce resource quotas (if not set)
kubectl apply -f kubernetes/base/resource-quotas.yaml

# Scale down non-critical workloads
kubectl scale deployment <deployment-name> -n <namespace> --replicas=1
```

### Long-term Fix
- Implement Vertical Pod Autoscaler (VPA)
- Review application for memory leaks
- Adjust node group instance types (more memory)

---

## 4. Certificate Expiration

**Symptom**: TLS errors, webhook failures, ingress not working

### Diagnostic Steps
```bash
# Check certificate expiry
kubectl get certificates --all-namespaces

# Check cert-manager (if used)
kubectl get certificaterequests --all-namespaces

# Manually check certificate expiry
kubectl get secret <tls-secret> -n <namespace> -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -dates
```

### Resolution
```bash
# If using cert-manager, trigger renewal
kubectl delete certificaterequest <name> -n <namespace>

# If manual certificate, rotate:
# 1. Generate new certificate
# 2. Update secret
kubectl create secret tls <secret-name> \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem \
  --namespace=<namespace> \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods using the certificate
kubectl rollout restart deployment <deployment-name> -n <namespace>
```

### Prevention
- Set up Prometheus alerts for certificates expiring in 30 days
- Use cert-manager for automated renewal
- Document manual certificate renewal procedures

---

## 5. GitOps Sync Failure

**Symptom**: ArgoCD shows Out Of Sync, applications not deploying

### Diagnostic Steps
```bash
# Check ArgoCD application status
argocd app list
argocd app get <app-name>

# View sync errors
argocd app get <app-name> --show-operation

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### Common Causes
1. **Invalid YAML**: Syntax error in manifest
2. **RBAC Restrictions**: ArgoCD lacks permissions
3. **Resource Conflicts**: Resource already exists with different ownership
4. **Git Authentication**: Can't access repository

### Resolution
```bash
# Manually sync application
argocd app sync <app-name>

# If YAML invalid, check locally
kubectl apply --dry-run=client -f path/to/manifest.yaml

# Force sync (use with caution)
argocd app sync <app-name> --force

# Check ArgoCD service account permissions
kubectl auth can-i create deployment --as=system:serviceaccount:argocd:argocd-application-controller
```

### Prevention
- Pre-commit hooks to validate YAML syntax
- CI pipeline to run `kubectl apply --dry-run`
- Test changes in dev environment first

---

## 6. Control Plane API Latency

**Symptom**: `kubectl` commands slow, API timeouts

### Diagnostic Steps
```bash
# Check EKS control plane health
aws eks describe-cluster --name dev-eks-cluster --query 'cluster.status'

# Check API server logs in CloudWatch
aws logs tail /aws/eks/dev-eks-cluster/cluster --follow

# Measure API latency
time kubectl get nodes
```

### Common Causes
1. **Control Plane Overload**: Too many API calls
2. **Network Issues**: VPC routing, security groups
3. **etcd Performance**: Control plane backing store slow
4. **Webhooks**: Slow admission webhooks

### Resolution
```bash
# Identify high API call sources
# Check control plane metrics in CloudWatch

# If admission webhook slow, check webhook latency
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations

# Temporarily bypass webhook (emergency only)
kubectl delete validatingwebhookconfiguration <name>

# Check for excessive polling
kubectl get --raw /metrics | grep apiserver_request_duration_seconds
```

### Escalation
- Open AWS Support ticket for control plane issues
- This is an AWS-managed component, limited remediation on our side

---

## 7. Disaster Recovery

**Scenario**: Complete environment loss (region failure, accidental deletion)

### Prerequisites
- Terraform state backed up in S3 (versioned)
- GitOps repository available
- AWS credentials valid

### Recovery Steps

#### Phase 1: Assess Damage (15 minutes)
```bash
# Check what's still running
aws eks list-clusters --region eu-west-1
aws ec2 describe-vpcs --region eu-west-1

# Verify Terraform state intact
aws s3 ls s3://cloud-platform-terraform-state/

# Verify Git repositories accessible
git clone git@github.com:your-org/cloud-platform.git
```

#### Phase 2: Rebuild Infrastructure (2 hours)
```bash
# Start with backend (if lost)
cd terraform/backend
terraform init
terraform apply

# Rebuild networking
cd terraform/networking
terraform init
terraform apply -var="environment=dev"

# Rebuild IAM
cd terraform/iam
terraform init
terraform apply

# Rebuild EKS
cd terraform/eks
terraform init
terraform apply
```

#### Phase 3: Restore Platform Services (1 hour)
```bash
# Configure kubectl
aws eks update-kubeconfig --region eu-west-1 --name dev-eks-cluster

# Apply base Kubernetes resources
kubectl apply -f kubernetes/base/

# Install Helm charts (monitoring, logging, etc.)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring -f kubernetes/monitoring/prometheus-values.yaml

# Install ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd -f kubernetes/applications/argocd-values.yaml
```

#### Phase 4: Restore Applications (30 minutes)
```bash
# ArgoCD will sync applications automatically once running
# Monitor sync status
argocd app list
argocd app sync --all
```

#### Phase 5: Validation (30 minutes)
```bash
# Verify all nodes healthy
kubectl get nodes

# Verify all pods running
kubectl get pods --all-namespaces

# Verify application endpoints
curl <application-url>

# Check monitoring
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

### Post-Recovery
- Document what happened
- Update runbooks with lessons learned
- Review and test backup/restore procedures
- Conduct post-mortem meeting

### RTO/RPO
- **RTO**: 4 hours (worst case, complete rebuild)
- **RPO**: 1 hour (Terraform state versioning)

---

## Emergency Contacts

- **Platform Lead**: [name] - [phone]
- **AWS Support**: Enterprise Support Portal
- **Security Team**: [security@company.com]
- **On-call Engineer**: Check PagerDuty rotation

## Post-Incident Process

1. Create incident ticket in JIRA/ServiceNow
2. Document timeline and actions taken
3. Schedule post-mortem within 48 hours
4. Update runbooks based on learnings
5. Implement preventative measures
