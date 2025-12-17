# Security Documentation

## Security Model

This platform implements a **Zero Trust** security model with defense-in-depth layering.

## Threat Model

### Assets to Protect
1. Application workloads and data
2. Kubernetes control plane
3. AWS credentials and secrets
4. Customer data (when deployed)
5. Infrastructure configuration

### Threat Actors
1. **External attackers**: Internet-based threats
2. **Malicious insiders**: Compromised credentials or rogue employees
3. **Supply chain**: Compromised container images or dependencies
4. **Misconfiguration**: Human error in IaC or deployments

## Security Controls

### 1. Network Security

#### VPC Isolation
- **Control**: Dedicated VPC with RFC1918 private addressing
- **Rationale**: Network-level isolation from other workloads
- **Implementation**: `terraform/networking/main.tf`

#### Private Subnets for Workloads
- **Control**: EKS nodes deployed in private subnets only
- **Rationale**: Workers never exposed to internet, egress through NAT
- **Implementation**: Nodes use `private_subnet_ids` only

#### Network Policies
- **Control**: Default-deny ingress in application namespace
- **Rationale**: Explicit allow-list prevents lateral movement
- **Implementation**: `kubernetes/base/network-policies.yaml`
- **Limitation**: Requires CNI support (AWS VPC CNI supports network policies via security groups)

#### VPC Flow Logs
- **Control**: All VPC traffic logged to CloudWatch
- **Rationale**: Network forensics, anomaly detection
- **Retention**: 30 days
- **Implementation**: `terraform/networking/main.tf` (lines 176-240)

### 2. Identity & Access Management

#### IRSA (IAM Roles for Service Accounts)
- **Control**: Pod-level AWS permissions via OIDC federation
- **Rationale**: Eliminates shared credentials, supports least privilege
- **Implementation**: `terraform/iam/main.tf`
- **Services Using IRSA**:
  - Cluster Autoscaler
  - AWS Load Balancer Controller
  - External Secrets Operator
  - EBS CSI Driver

#### Least Privilege IAM Policies
- **Control**: Scoped-down permissions per service
- **Example**: Cluster Autoscaler can only modify ASGs with specific tags
- **Review Cadence**: Quarterly policy audits recommended

#### No Long-Lived Credentials
- **Control**: No AWS access keys stored in cluster
- **Rationale**: Reduces blast radius of credential compromise
- **Implementation**: All AWS access via IRSA or node IAM roles

### 3. Pod Security

#### Pod Security Standards
- **Control**: Kubernetes built-in admission controller enforcing:
  - **Restricted** profile for application workloads
  - **Baseline** profile for platform services (monitoring, logging)
- **Rationale**: Prevents privileged containers, host path mounts, privilege escalation
- **Implementation**: `kubernetes/base/pod-security-standards.yaml`

**Restricted Profile Enforces**:
- No privileged containers
- No host namespaces (network, PID, IPC)
- No host path volumes
- Runs as non-root
- Drops all capabilities
- Enforces read-only root filesystem

#### Resource Limits
- **Control**: LimitRanges and ResourceQuotas per namespace
- **Rationale**: Prevents resource exhaustion DoS attacks
- **Implementation**: `kubernetes/base/resource-quotas.yaml`

#### Container Image Security
- **Best Practice** (not yet implemented):
  - Image scanning with Trivy/Grype in CI pipeline
  - Private ECR for vetted images
  - Image pull policies set to `Always` for latest security patches

### 4. Secrets Management

#### AWS Secrets Manager Integration
- **Control**: External Secrets Operator syncs secrets from AWS Secrets Manager
- **Rationale**: Centralized secret management, rotation, audit trail
- **Implementation**: `kubernetes/monitoring/secret-store-example.yaml`

#### No Secrets in Git
- **Control**: All sensitive values loaded at runtime
- **Enforcement**: `.gitignore` patterns, pre-commit hooks (recommended)

#### Encryption at Rest
- **EKS Secrets**: Encrypted with AWS KMS (when configured)
- **S3 State**: AES256 encryption
- **EBS Volumes**: Encrypted by default in EKS

### 5. Control Plane Security

#### Private API Endpoint
- **Control**: Control plane accessible via private VPC endpoint
- **Current State**: Public endpoint enabled with CIDR restrictions
- **Production Recommendation**: Disable public endpoint, use VPN/bastion for admin access

#### Audit Logging
- **Control**: All EKS control plane logs enabled:
  - API server
  - Audit
  - Authenticator
  - Controller manager
  - Scheduler
- **Destination**: CloudWatch Logs
- **Retention**: 90 days (adjustable)
- **Use Cases**: Compliance, incident investigation, anomaly detection

#### RBAC (Role-Based Access Control)
- **Control**: Kubernetes RBAC for cluster access
- **Best Practice** (to be implemented):
  - AWS IAM users/roles mapped to K8s RBAC groups
  - Separate roles for: admins, developers, read-only
  - No cluster-admin for daily operations

### 6. Supply Chain Security

#### Terraform State Security
- **Control**: Remote state in S3 with:
  - Versioning enabled (rollback capability)
  - Encryption at rest
  - DynamoDB locking (prevents concurrent writes)
  - Bucket public access blocked
- **Implementation**: `terraform/backend/main.tf`

#### Container Image Provenance
- **Recommended** (not yet implemented):
  - Sign images with Cosign
  - Enforce signature verification with admission controller
  - SBOM (Software Bill of Materials) generation

### 7. Observability for Security

#### Centralized Logging
- **Control**: All container logs shipped to CloudWatch
- **Use Cases**: Security event correlation, compliance
- **Implementation**: `kubernetes/logging/fluent-bit-values.yaml`

#### Prometheus Monitoring
- **Security Metrics** (to be added):
  - Failed authentication attempts
  - Unexpected network connections
  - Resource quota violations
  - Privilege escalation attempts

## Incident Response

### Detection
1. **CloudWatch Alarms**: CPU spikes, error rate increases
2. **Prometheus Alerts**: Pod crash loops, certificate expiry
3. **VPC Flow Logs**: Unusual traffic patterns

### Response Playbook
1. **Identify**: Alert triggers investigation
2. **Contain**: Network policies isolate affected namespace
3. **Eradicate**: Rollback via GitOps, redeploy clean images
4. **Recover**: Restore from backup if needed
5. **Lessons Learned**: Update runbooks, improve detection

## Compliance Mapping

### CIS Kubernetes Benchmark
| Control | Implementation | Status |
|---------|----------------|--------|
| 5.2.x Pod Security Standards | `pod-security-standards.yaml` | ✅ Implemented |
| 5.3.x Network Policies | `network-policies.yaml` | ✅ Implemented |
| 5.4.x Secrets Management | External Secrets Operator | ✅ Implemented |
| 5.7.x RBAC | Kubernetes native | ⚠️ Needs configuration |

### AWS Security Best Practices
| Control | Implementation | Status |
|---------|----------------|--------|
| Least privilege IAM | Scoped IRSA policies | ✅ Implemented |
| Encryption at rest | S3, EBS, Secrets Manager | ✅ Implemented |
| VPC isolation | Private subnets, NACLs | ✅ Implemented |
| Logging enabled | CloudWatch, VPC Flow Logs | ✅ Implemented |
| MFA for admins | AWS IAM | ⚠️ Out of scope (org-level) |

## Security Gaps & Roadmap

### Short Term (1-3 months)
1. ✅ Implement IRSA for all AWS integrations
2. ⚠️ Configure EKS encryption provider (KMS)
3. ⚠️ Set up AWS GuardDuty for threat detection
4. ⚠️ Implement image scanning in CI pipeline

### Medium Term (3-6 months)
1. Deploy Falco for runtime security monitoring
2. Implement OPA/Gatekeeper for policy enforcement
3. Set up AWS Security Hub for centralized findings
4. Conduct penetration testing

### Long Term (6-12 months)
1. Implement service mesh (Istio) for mTLS
2. Zero-trust network with mutual authentication
3. Automated vulnerability remediation pipeline
4. SOC 2 Type II certification preparation

## Security Contacts

- **Platform Team**: [your-team@company.com]
- **Security Incidents**: [security@company.com]
- **AWS Support**: Enterprise support ticket

## References

- [AWS EKS Security Best Practices](https://aws.github.io/aws-eks-best-practices/security/docs/)
- [Kubernetes Security Documentation](https://kubernetes.io/docs/concepts/security/)
- [CIS Benchmarks](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
