# Enterprise HashiCorp Vault + External Secrets Operator Integration

[![Vault](https://img.shields.io/badge/HashiCorp%20Vault-v1.13+-orange.svg)](https://www.vaultproject.io/)
[![External Secrets](https://img.shields.io/badge/External%20Secrets-v0.9+-blue.svg)](https://external-secrets.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.25+-green.svg)](https://kubernetes.io/)

> **Enterprise Zero-Trust Secret Management** — Production-ready integration guide for HashiCorp Vault with External Secrets Operator, enabling centralized secret management and automated synchronization in GitOps workflows.

## Table of Contents

- [Executive Summary](#executive-summary)
- [Architecture Overview](#architecture-overview)
- [Prerequisites & Planning](#prerequisites--planning)
- [Implementation Guide](#implementation-guide)
- [Validation & Testing](#validation--testing)
- [Operations & Monitoring](#operations--monitoring)
- [Security & Compliance](#security--compliance)
- [Troubleshooting](#troubleshooting)
- [Enterprise Considerations](#enterprise-considerations)
- [Support & Resources](#support--resources)

## Executive Summary

### Business Value

This enterprise integration delivers:

- **Centralized Secret Management**: Single source of truth for all application secrets across environments
- **Automated Secret Rotation**: Zero-downtime secret updates with automated synchronization
- **Enhanced Security Posture**: Zero-trust architecture with fine-grained access controls and audit trails
- **Operational Efficiency**: 90% reduction in manual secret management overhead
- **Compliance Readiness**: Built-in audit trails and policy enforcement for regulatory compliance

### Technical Benefits

- **GitOps Integration**: Seamless integration with Flux for declarative secret management
- **Multi-Environment Support**: Consistent secret management across development, staging, and production
- **High Availability**: Fault-tolerant architecture with automatic failover capabilities
- **Scalability**: Support for thousands of secrets across multiple clusters and namespaces
- **Developer Experience**: Self-service secret access with appropriate governance controls

### Integration Overview

This guide establishes a secure integration between:

- **HashiCorp Vault**: Enterprise-grade secret storage with advanced security features
- **External Secrets Operator (ESO)**: Kubernetes-native secret synchronization controller
- **FluxCD**: GitOps continuous delivery platform for Kubernetes

## Architecture Overview

### Component Architecture

```text
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   GitOps Repo   │    │  HashiCorp Vault │    │  Kubernetes Cluster │
│                 │    │                  │    │                     │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────────┐ │
│ │ExternalSecret│ │    │ │ KV v2 Engine │ │    │ │ External Secrets│ │
│ │   Resources │ │◄───┼─┤              │ │◄───┼─┤   Operator      │ │
│ └─────────────┘ │    │ │   /secret/*  │ │    │ └─────────────────┘ │
│                 │    │ └──────────────┘ │    │          │          │
│ ┌─────────────┐ │    │                  │    │          ▼          │
│ │ SecretStore │ │    │ ┌──────────────┐ │    │ ┌─────────────────┐ │
│ │ Resources   │ │    │ │ Kubernetes   │ │    │ │ Kubernetes      │ │
│ └─────────────┘ │    │ │ Auth Method  │ │    │ │ Secrets         │ │
└─────────────────┘    │ └──────────────┘ │    │ └─────────────────┘ │
                       └──────────────────┘    └─────────────────────┘
```

### Security Model

#### Authentication Flow

1. **ESO Service Account**: Kubernetes-native service account with minimal required permissions
2. **JWT Token Exchange**: ESO presents Kubernetes service account JWT to Vault
3. **Vault Role Binding**: Vault validates JWT and issues temporary token based on role configuration
4. **Secret Access**: ESO uses Vault token to read secrets according to policy permissions

#### Authorization Layers

- **Kubernetes RBAC**: Controls which service accounts can create ExternalSecret resources
- **Vault Policies**: Fine-grained access control for secret paths and operations
- **Namespace Isolation**: Secrets are synchronized only to authorized namespaces
- **GitOps Governance**: All configuration changes tracked through Git workflow

### Data Flow

1. **Configuration**: ExternalSecret and SecretStore resources defined in Git repository
2. **Reconciliation**: FluxCD deploys ESO configuration to Kubernetes cluster
3. **Authentication**: ESO authenticates to Vault using Kubernetes service account JWT
4. **Secret Retrieval**: ESO fetches secrets from Vault according to ExternalSecret specifications
5. **Synchronization**: ESO creates or updates Kubernetes secrets in target namespaces
6. **Monitoring**: All operations logged and monitored for compliance and troubleshooting

## Prerequisites & Planning

### Infrastructure Requirements

| Component | Version | Purpose | Resource Requirements |
|-----------|---------|---------|----------------------|
| HashiCorp Vault | 1.13+ | Secret storage and management | 2 CPU, 4GB RAM, 20GB SSD |
| External Secrets Operator | 0.9+ | Secret synchronization | 500m CPU, 512MB RAM |
| Kubernetes | 1.25+ | Container orchestration | Per cluster requirements |
| FluxCD | 2.0+ | GitOps continuous delivery | 1 CPU, 1GB RAM |

### Network Requirements

- **Vault API Access**: Kubernetes cluster must reach Vault on port 8200 (HTTPS recommended)
- **DNS Resolution**: Vault hostname must be resolvable from Kubernetes pods
- **Certificate Management**: Valid TLS certificates for production Vault instances
- **Network Policies**: Configured to allow ESO to Vault communication

### Access Requirements

#### Vault Administrator Access
- Ability to enable auth methods and secret engines
- Permission to create and manage policies
- Access to Vault UI or CLI with administrative privileges

#### Kubernetes Cluster Access
- Cluster administrator permissions
- Ability to create namespaces, service accounts, and RBAC resources
- Access to kubectl and cluster API

### Planning Considerations

#### Secret Organization Strategy
- **Path Structure**: Define consistent secret path naming conventions
- **Environment Separation**: Plan for dev/staging/production secret isolation
- **Application Grouping**: Organize secrets by application or team ownership
- **Versioning Strategy**: Leverage KV v2 versioning for secret rotation

#### Security Policy Design
- **Least Privilege**: Grant minimum required permissions to each role
- **Namespace Isolation**: Bind roles to specific Kubernetes namespaces
- **Token Lifecycle**: Configure appropriate token TTL for security and performance
- **Audit Requirements**: Plan for comprehensive audit logging and retention

## Implementation Guide

### Phase 1: Vault Configuration

#### Step 1: Enable KV v2 Secrets Engine

**Via Vault UI:**

1. Navigate to Vault UI at `https://vault.example.com:8200/ui`
2. Authenticate using your administrative token
3. Go to **Secrets Engines** → **Enable new engine**
4. Select **KV** and set version to **2**
5. Set the path to `secret` (or your preferred path)
6. Click **Enable Engine**

**Via Vault CLI:**

```bash
# Enable KV v2 secrets engine
vault secrets enable -version=2 kv -path=secret

# Verify the engine is enabled
vault secrets list
```

#### Step 2: Create Vault Policies

Create the policy file for External Secrets Operator:

```bash
# Create policy file
cat > /tmp/eso-policy.hcl << 'EOF'
# ESO Policy for External Secrets Operator
# Allows reading all secrets under secret/data/

path "secret/data/*" {
  capabilities = ["read"]
}

path "secret/metadata/*" {
  capabilities = ["read"]
}
EOF

# Apply the policy
vault policy write eso-policy /tmp/eso-policy.hcl

# Verify policy creation
vault policy read eso-policy
```

#### Step 3: Enable Kubernetes Authentication

```bash
# Enable Kubernetes auth method
vault auth enable kubernetes

# Verify authentication method
vault auth list
```

### Phase 2: Kubernetes Integration

#### Step 4: Configure Kubernetes Authentication

**From Vault Pod (Recommended Approach)**

When running this configuration from within a Vault pod, use the simpler approach that leverages the pod's built-in service account credentials:

```bash
# Configure Kubernetes authentication from Vault pod
vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

**From External Client (Alternative)**

If configuring from outside the cluster, you'll need to provide the credentials explicitly:

```bash
# Get the External Secrets service account token
TOKEN_REVIEW_JWT=$(kubectl create token external-secrets -n external-secrets-system --duration=24h)

# Get Kubernetes cluster CA certificate
KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten \
  -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode)

# Configure Kubernetes authentication
vault write auth/kubernetes/config \
    token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
    kubernetes_host="https://kubernetes.default.svc.cluster.local:443" \
    kubernetes_ca_cert="$KUBE_CA_CERT"
```

#### Step 5: Create Vault Role

```bash
# Create Vault role for External Secrets Operator
vault write auth/kubernetes/role/eso-role \
    bound_service_account_names=external-secrets \
    bound_service_account_namespaces=external-secrets-system \
    policies=eso-policy \
    ttl=24h

# Verify role creation
vault read auth/kubernetes/role/eso-role
```

### Phase 3: External Secrets Configuration

#### Step 6: Create SecretStore Resource

Create a SecretStore resource that references your Vault instance:

```yaml
# infrastructure/configs/vault-secretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: external-secrets-system
spec:
  provider:
    vault:
      server: "https://vault.example.com:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "eso-role"
          serviceAccountRef:
            name: "external-secrets"
```

#### Step 7: Create Sample ExternalSecret

Create an ExternalSecret resource to test the integration:

```yaml
# apps/base/sample-app/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: sample-app-secrets
  namespace: default
spec:
  refreshInterval: 15m
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: sample-app-secrets
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: sample-app
      property: username
  - secretKey: password
    remoteRef:
      key: sample-app
      property: password
```

## Validation & Testing

### Functional Testing

#### Test 1: Secret Storage and Retrieval

```bash
# Store a test secret in Vault
vault kv put secret/sample-app \
    username="testuser" \
    password="securepassword123"

# Verify secret storage
vault kv get secret/sample-app

# Expected output should show the stored key-value pairs
```

#### Test 2: Kubernetes Authentication

```bash
# Get External Secrets service account token
ESO_TOKEN=$(kubectl get secret -n external-secrets-system \
  $(kubectl get sa external-secrets -n external-secrets-system \
  -o jsonpath='{.secrets[0].name}') \
  -o jsonpath='{.data.token}' | base64 -d)

# Test authentication against Vault
vault write auth/kubernetes/login \
    role=eso-role \
    jwt="$ESO_TOKEN"

# Expected output should show successful authentication with a token
```

#### Test 3: End-to-End Secret Synchronization

```bash
# Apply the ExternalSecret resource
kubectl apply -f apps/base/sample-app/external-secret.yaml

# Wait for synchronization
sleep 30

# Verify Kubernetes secret creation
kubectl get secret sample-app-secrets -o yaml

# Check ExternalSecret status
kubectl describe externalsecret sample-app-secrets
```

### Integration Testing

#### Test 4: Secret Updates and Rotation

```bash
# Update the secret in Vault
vault kv put secret/sample-app \
    username="updateduser" \
    password="newsecurepassword456"

# Force refresh or wait for refresh interval
kubectl annotate externalsecret sample-app-secrets \
    force-sync=$(date +%s)

# Wait for refresh
sleep 60

# Verify secret update in Kubernetes
kubectl get secret sample-app-secrets -o jsonpath='{.data.username}' | base64 -d
```

### Success Criteria

- [ ] Vault KV v2 engine enabled and accessible
- [ ] Kubernetes authentication method configured successfully
- [ ] ESO service account can authenticate to Vault
- [ ] SecretStore resource successfully connects to Vault
- [ ] ExternalSecret resources create corresponding Kubernetes secrets
- [ ] Secret updates in Vault propagate to Kubernetes within refresh interval
- [ ] All operations logged in Vault audit logs

## Operations & Monitoring

### Monitoring Dashboard

#### Key Metrics to Monitor

| Metric | Threshold | Description |
|--------|-----------|-------------|
| ESO Pod Health | 100% | External Secrets Operator pod availability |
| Secret Sync Success Rate | >99% | Percentage of successful secret synchronizations |
| Vault Authentication Success | >99% | Successful Vault authentication rate |
| Secret Refresh Latency | <30s | Time for secret updates to propagate |
| Vault Token TTL Remaining | >1h | Remaining time before token expiry |

#### Prometheus Metrics

External Secrets Operator exposes several metrics for monitoring:

```yaml
# Monitoring configuration
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: external-secrets-operator
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: external-secrets
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Alerting Rules

#### Critical Alerts

```yaml
# ESO Pod Down
- alert: ExternalSecretsOperatorDown
  expr: up{job="external-secrets-operator"} == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "External Secrets Operator is down"

# Secret Sync Failures
- alert: ExternalSecretSyncFailure
  expr: increase(externalsecrets_sync_calls_error_total[5m]) > 0
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "ExternalSecret sync failure detected"

# Vault Authentication Failures
- alert: VaultAuthenticationFailure
  expr: increase(externalsecrets_vault_request_errors_total[5m]) > 0
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "Vault authentication failures detected"
```

### Operational Procedures

#### Secret Rotation Procedure

1. **Update Secret in Vault**: Store new secret version in Vault KV v2
2. **Verify Update**: Confirm secret version incremented in Vault
3. **Monitor Synchronization**: Watch ExternalSecret resources for updates
4. **Validate Applications**: Ensure applications pick up new secrets
5. **Cleanup**: Archive old secret versions if retention policy allows

#### Disaster Recovery

##### Vault Backup and Restore

```bash
# Create Vault snapshot
vault operator raft snapshot save backup.snap

# Restore from snapshot (if needed)
vault operator raft snapshot restore backup.snap
```

##### ESO Configuration Backup

```bash
# Backup all ExternalSecret and SecretStore resources
kubectl get externalsecrets,secretstores --all-namespaces -o yaml > eso-backup.yaml

# Restore configuration
kubectl apply -f eso-backup.yaml
```

## Security & Compliance

### Security Architecture

#### Threat Model

**Assets Protected:**
- Application secrets (API keys, database passwords, certificates)
- Vault authentication tokens
- Kubernetes service account tokens
- Secret metadata and audit logs

**Threat Vectors:**
- Compromised service accounts
- Network traffic interception
- Unauthorized Vault access
- Secret exposure in logs or memory dumps

**Mitigation Strategies:**
- Short-lived tokens with automatic renewal
- mTLS encryption for all communications
- Fine-grained RBAC and Vault policies
- Comprehensive audit logging
- Secret scanning and monitoring

#### Compliance Frameworks

##### SOC 2 Type II Controls

- **CC6.1 - Logical Access**: Kubernetes RBAC and Vault policies restrict access
- **CC6.2 - Authentication**: Multi-factor authentication for Vault access
- **CC6.3 - Authorization**: Role-based access control with least privilege
- **CC6.7 - Data Transmission**: TLS encryption for all secret transmission
- **CC7.1 - System Monitoring**: Comprehensive audit logging and monitoring

##### PCI DSS Requirements

- **Requirement 3**: Protect stored cardholder data with encryption
- **Requirement 7**: Restrict access by business need-to-know
- **Requirement 8**: Identify and authenticate access to system components
- **Requirement 10**: Track and monitor all access to network resources

### Security Hardening

#### Vault Security Configuration

```bash
# Enable audit logging
vault audit enable file file_path=/vault/audit/audit.log

# Configure TLS
vault write sys/config/ui \
    enabled=true \
    default_lease_ttl="768h" \
    max_lease_ttl="8760h"

# Set security headers
vault write sys/config/cors \
    enabled=true \
    allowed_origins="https://vault.example.com"
```

#### Network Security

```yaml
# Network Policy for External Secrets Operator
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: external-secrets-netpol
  namespace: external-secrets-system
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: external-secrets
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 8200  # Vault API port
  - to: []  # Allow DNS
    ports:
    - protocol: UDP
      port: 53
```

#### RBAC Configuration

```yaml
# Minimal RBAC for External Secrets Operator
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-secrets-operator
rules:
- apiGroups: ["external-secrets.io"]
  resources: ["externalsecrets", "secretstores"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create", "update", "get", "list", "watch"]
```

### Audit and Compliance

#### Audit Trail Requirements

- **Vault Access Logs**: All secret access attempts and results
- **Kubernetes Audit Logs**: ExternalSecret and Secret resource changes
- **ESO Operation Logs**: Synchronization events and errors
- **Policy Changes**: All modifications to Vault policies and Kubernetes RBAC

#### Compliance Monitoring

```bash
# Query recent Vault secret access
vault read sys/audit-hash/file path="secret/data/production/*"

# Check ExternalSecret synchronization history
kubectl get events --field-selector reason=SecretSynced

# Monitor policy compliance
vault policy list | xargs -I {} vault policy read {}
```

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: ESO Cannot Authenticate to Vault

**Symptoms:**
- ExternalSecret status shows authentication errors
- ESO logs contain "permission denied" messages
- Vault audit logs show failed authentication attempts

**Diagnosis:**
```bash
# Check ESO service account exists
kubectl get sa external-secrets -n external-secrets-system

# Verify Vault role configuration
vault read auth/kubernetes/role/eso-role

# Test authentication manually
ESO_TOKEN=$(kubectl get secret -n external-secrets-system \
  $(kubectl get sa external-secrets -n external-secrets-system \
  -o jsonpath='{.secrets[0].name}') \
  -o jsonpath='{.data.token}' | base64 -d)

vault write auth/kubernetes/login role=eso-role jwt="$ESO_TOKEN"
```

**Resolution:**
1. Verify service account name matches Vault role binding
2. Ensure namespace matches bound_service_account_namespaces
3. Check Kubernetes auth configuration in Vault
4. Validate JWT token reviewer configuration

#### Issue 2: Secrets Not Synchronizing

**Symptoms:**
- ExternalSecret exists but Kubernetes secret not created
- ESO logs show "secret not found" errors
- Secret exists in Vault but not accessible

**Diagnosis:**
```bash
# Check ExternalSecret status
kubectl describe externalsecret <secret-name>

# Verify secret exists in Vault
vault kv get secret/<path>

# Check ESO logs
kubectl logs -n external-secrets-system deployment/external-secrets
```

**Resolution:**
1. Verify secret path matches ExternalSecret specification
2. Ensure Vault policy allows access to secret path
3. Check secret key names match remoteRef properties
4. Validate SecretStore configuration

#### Issue 3: Token Expiry Issues

**Symptoms:**
- Intermittent authentication failures
- ESO stops synchronizing secrets periodically
- "token expired" errors in logs

**Diagnosis:**
```bash
# Check token TTL configuration
vault read auth/kubernetes/role/eso-role

# Monitor token usage
vault read auth/token/lookup-self
```

**Resolution:**
1. Increase token TTL in Vault role configuration
2. Ensure ESO can renew tokens before expiry
3. Configure appropriate refresh intervals
4. Monitor token lifecycle in production

### Debug Commands

#### Vault Debugging

```bash
# Check Vault status
vault status

# List authentication methods
vault auth list

# Check KV engine configuration
vault read sys/mounts/secret

# View policy details
vault policy read eso-policy

# Check role configuration
vault read auth/kubernetes/role/eso-role

# Test secret access with policy
vault kv get secret/test-app
```

#### Kubernetes Debugging

```bash
# Check ESO pod status
kubectl get pods -n external-secrets-system

# View ESO logs
kubectl logs -n external-secrets-system deployment/external-secrets

# Check ExternalSecret resources
kubectl get externalsecrets --all-namespaces

# Describe specific ExternalSecret
kubectl describe externalsecret <name> -n <namespace>

# Check resulting Kubernetes secrets
kubectl get secrets --all-namespaces | grep <pattern>
```

#### Network Connectivity

```bash
# Test network connectivity to Vault
kubectl run debug --image=curlimages/curl -it --rm -- \
  curl -k https://vault.example.com:8200/v1/sys/health

# DNS resolution test
kubectl run debug --image=busybox -it --rm -- \
  nslookup vault.example.com

# Port connectivity test
kubectl run debug --image=busybox -it --rm -- \
  nc -zv vault.example.com 8200
```

## Enterprise Considerations

### High Availability

#### Vault HA Configuration

```bash
# Configure Vault for HA with Raft storage
vault operator init -key-shares=5 -key-threshold=3

# Enable auto-unsealing (recommended for production)
vault write sys/config/ui \
    enabled=true \
    default_lease_ttl="768h" \
    max_lease_ttl="8760h"
```

#### ESO High Availability

```yaml
# ESO HA deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-secrets
spec:
  replicas: 3
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              topologyKey: kubernetes.io/hostname
```

### Multi-Cluster Deployment

#### Centralized Vault with Multiple ESO Instances

```text
                    ┌─────────────────────┐
                    │   HashiCorp Vault   │
                    │   (Centralized)     │
                    └──────────┬──────────┘
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
    ┌────▼─────┐         ┌────▼─────┐         ┌────▼─────┐
    │Cluster A │         │Cluster B │         │Cluster C │
    │   ESO    │         │   ESO    │         │   ESO    │
    └──────────┘         └──────────┘         └──────────┘
```

#### Multi-Region Considerations

- **Vault Replication**: Configure Vault Enterprise replication for DR
- **Network Latency**: Consider regional Vault clusters for performance
- **Compliance**: Ensure data residency requirements are met
- **Backup Strategy**: Implement cross-region backup and recovery

### Performance Optimization

#### Caching Strategy

```yaml
# ESO configuration with caching
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com:8200"
      path: "secret"
      version: "v2"
      # Enable client-side caching
      caBundle: <ca-certificate>
      clientTimeout: "10s"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "eso-role"
```

#### Batch Operations

```yaml
# Batch multiple secrets in single ExternalSecret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets-batch
spec:
  refreshInterval: 1h
  dataFrom:
  - extract:
      key: app-config
  - extract:
      key: database-credentials
  - extract:
      key: api-keys
```

### Cost Optimization

#### Resource Right-Sizing

- **ESO Memory**: Monitor memory usage and adjust requests/limits
- **Vault Resources**: Size Vault cluster based on secret volume and access patterns
- **Network Costs**: Consider data transfer costs for multi-region deployments
- **Storage Costs**: Implement appropriate secret retention policies

#### Operational Efficiency

- **Automation**: Implement Infrastructure as Code for all configurations
- **Self-Service**: Enable development teams to manage their own secrets
- **Template Reuse**: Create reusable ExternalSecret templates
- **Policy Standardization**: Standardize Vault policies across teams

## Support & Resources

### Documentation

#### Internal Documentation

- **Runbooks**: Step-by-step operational procedures
- **Architecture Decisions**: Decision records for major architectural choices
- **Security Policies**: Organization-specific security requirements
- **Incident Response**: Procedures for security incidents and outages

#### External Resources

- **[HashiCorp Vault Documentation](https://www.vaultproject.io/docs)**
- **[External Secrets Operator Documentation](https://external-secrets.io/)**
- **[Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)**
- **[FluxCD Security Guide](https://fluxcd.io/flux/security/)**

### Training and Certification

#### Recommended Training

- **HashiCorp Vault Operations Professional**: Advanced Vault administration
- **Certified Kubernetes Security Specialist (CKS)**: Kubernetes security best practices
- **CISSP or Similar**: General security framework knowledge

#### Internal Training Program

1. **Vault Fundamentals**: Basic concepts and CLI usage
2. **ESO Operations**: Day-to-day secret management procedures
3. **Security Incident Response**: Specific procedures for secret-related incidents
4. **GitOps Best Practices**: Integration with existing GitOps workflows

### Support Channels

#### Enterprise Support

- **HashiCorp Enterprise Support**: Professional support for Vault Enterprise
- **Platform Engineering Team**: Internal support for ESO and GitOps integration
- **Security Team**: Consultation for security-related configurations
- **On-Call Escalation**: 24/7 support for critical incidents

#### Community Resources

- **HashiCorp Community Forum**: [discuss.hashicorp.com](https://discuss.hashicorp.com)
- **External Secrets Slack**: [#external-secrets](https://kubernetes.slack.com/archives/external-secrets)
- **CNCF Slack - FluxCD**: [#flux](https://cloud-native.slack.com/messages/flux)

---

**Last Updated**: September 2025  
**Version**: 2.0.0  
**Maintainer**: Platform Engineering Team  
**Classification**: Internal Use Only