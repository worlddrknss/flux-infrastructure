HashiCorp Vault + External Secrets Operator Integration Guide for Flux
=============================================================================

> **Note**: This is publication is based on K3S, and may require refinement for production use.

Purpose
-------

This document provides a comprehensive guide for configuring HashiCorp Vault to work with External Secrets Operator (ESO) and Flux for secure secret management in Kubernetes. By the end of this guide, you'll have a fully configured Vault instance that can provide secrets to your Flux-managed GitOps workflows through ESO.

## Overview

This integration enables:
- **Centralized secret management** in HashiCorp Vault
- **Runtime secret synchronization** via External Secrets Operator
- **Secure authentication** between ESO and Vault using Kubernetes auth
- **Audit trail** of all secret access through Vault logs

## TL;DR

1. Enable Vault's KV v2 secrets engine for storing secrets
2. Create a minimal ACL policy allowing read operations on secrets
3. Configure Kubernetes authentication in Vault
4. Bind External Secrets service account to a Vault role with the appropriate policy

Prerequisites
-------------

Before beginning this configuration, ensure you have:

- **Vault Server**: A running HashiCorp Vault instance accessible via UI/API (e.g., `http://<vault-node-ip>:8200/ui`)
- **Vault Access**: Admin-level token or root access to configure auth methods and policies  
- **Kubernetes Cluster**: Access to the cluster where Flux and ESO are installed with permissions to manage service accounts
- **External Secrets Operator**: ESO installed in your cluster (typically in `external-secrets` namespace)
- **Flux Installation**: A working Flux installation in your cluster
- **Tools** (optional): `vault` CLI and `jq` for automation scripts and verification

## Variables and Placeholders

Throughout this guide, replace these placeholders with your actual values:

- `<vault-node-ip>` — IP address or hostname of your Vault server
- `<token-reviewer-jwt>` — JWT token used by Vault to validate Kubernetes service accounts
- `external-secrets` — Namespace where External Secrets Operator runs (adjust if different)

Implementation Steps
--------------------

### Step 1: Access Vault UI

1. Open your browser and navigate to the Vault UI: `http://<vault-node-ip>:8200/ui`
2. Authenticate using your admin token (typically `root` or another administrative token)

### Step 2: Enable KV v2 Secrets Engine

1. In the left navigation panel, click **Secrets Engines**
2. Click **Enable new engine** 
3. Select **KV** from the list of available engines
4. Set the version to **2** and keep the default path as `secret`
5. Click **Enable Engine**

### Step 3: Create Vault Policy for External Secrets Operator

1. Navigate to **Access** → **Policies** → **Create ACL Policy**
2. Set the policy name to: `eso-policy`
3. Enter the following policy content:

```hcl
path "secret/data/*" {
  capabilities = ["read"]
}
```

4. Click **Create policy** to save

This policy grants External Secrets Operator the ability to read all secrets stored in the KV v2 secrets engine.

### Step 4: Enable Kubernetes Authentication

1. Navigate to **Access** → **Auth Methods**
2. Click **Enable new method** and select **Kubernetes**
3. Keep the default path as `kubernetes` and click **Enable Method**

### Step 5: Configure Kubernetes Authentication

1. Click into the newly enabled `kubernetes` auth method
2. Go to **Configuration** and provide the following details:
   - **Kubernetes Host**: `https://kubernetes.default.svc.cluster.local`
   - **CA Certificate**: Paste the contents from `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`
   - **Token Reviewer JWT**: Paste the JWT token for a service account with TokenReview permissions.
     - Generate a JWT token: `kubectl -n external-secrets create token external-secrets`
3. Click **Save** to store the configuration

### Step 6: Create Vault Role for External Secrets Operator

1. While still in the `kubernetes` auth method, navigate to **Roles** → **Create Role**
2. Configure the role with these settings:
   - **Role name**: `eso-role`
   - **Bound service account names**: `external-secrets`
   - **Bound service account namespaces**: `external-secrets`
   - **Generated token's policies**: `eso-policy`
   - **Generated token's TTL**: `1h` (or as appropriate for your security requirements)
3. Click **Create role** to save

## CLI Configuration Steps

For automation or script-based deployment, use these Vault CLI commands:

> **Note**: Run within a vault pod. Eg vault-0

```bash
# Ensure you're authenticated to Vault
export VAULT_ADDR="http://<vault-node-ip>:8200"
export VAULT_TOKEN="<your-admin-token>"

# Enable Kubernetes authentication
vault auth enable kubernetes

# Configure Kubernetes authentication
vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Create the Vault role for External Secrets Operator
vault write auth/kubernetes/role/eso-role \
    bound_service_account_names=external-secrets \
    bound_service_account_namespaces=external-secrets \
    policies=eso-policy \
    ttl=1h

# Create the policy file
cat <<'EOF' > eso-policy.hcl
path "secret/data/*" {
  capabilities = ["read"]
}
EOF

# Apply the policy
vault policy write eso-policy eso-policy.hcl
```

## Verification

### Testing Secret Access

Verify that your configuration is working correctly:

```bash
# Create a test secret in Vault
vault kv put secret/test-app username=testuser password=testpass

# Verify the secret was created
vault kv get secret/test-app
```

### Verifying Kubernetes Auth

Test that the External Secrets service account can authenticate:

```bash
# Get the service account token
SA_TOKEN=$(kubectl get secret -n external-secrets \
  $(kubectl get sa external-secrets -n external-secrets -o jsonpath='{.secrets[0].name}') \
  -o jsonpath='{.data.token}' | base64 -d)

# Test authentication
vault write auth/kubernetes/login \
  role=eso-role \
  jwt="$SA_TOKEN"
```

## Troubleshooting

### Common Issues

**External Secrets Operator cannot read secrets from Vault:**

- Verify the Vault policy paths are correct (must use `secret/data/*` for KV v2)
- Check that the Vault role is bound to the correct service account name and namespace
- Ensure the Kubernetes auth configuration has the correct cluster CA certificate and token reviewer JWT
- Review Vault audit logs for authentication or authorization failures

**Authentication failures:**

- Confirm the `external-secrets` service account exists in the `external-secrets` namespace
- Verify the service account has the necessary RBAC permissions
- Check that the bound service account names in the Vault role match exactly

**Policy issues:**

- Ensure the policy name is referenced correctly in the Vault role
- Verify the secret paths match your KV engine mount path
- Check that capabilities include `["read"]` for the secret paths

### Debug Commands

```bash
# Check Vault status
vault status

# List enabled auth methods
vault auth list

# Check if KV engine is enabled
vault secrets list

# View policy details
vault policy read eso-policy

# List roles for kubernetes auth
vault list auth/kubernetes/role

# Test secret access
vault kv get secret/test-app
```

## Security Considerations

### Access Control

- **Principle of Least Privilege**: The provided policy grants only read permissions to secrets
- **Service Account Binding**: Roles are bound to specific service accounts in specific namespaces
- **Token TTL**: Configure appropriate token lifetimes (1h is recommended for ESO)

### Monitoring and Auditing

- **Enable Vault Auditing**: Configure audit logging to track all secret access
- **Monitor Failed Attempts**: Set up alerting for authentication and authorization failures  
- **Regular Access Reviews**: Periodically review and rotate service account tokens

### Secret Management

- **Secret Organization**: Use consistent paths and naming conventions for secrets
- **Versioning**: Leverage KV v2's versioning capabilities for secret rotation
- **Backup Strategy**: Ensure Vault backups include all secret data

### Network Security

- **TLS Encryption**: Always use HTTPS/TLS for Vault communication in production
- **Network Policies**: Restrict network access to Vault using Kubernetes Network Policies
- **Firewall Rules**: Limit Vault access to necessary ports and IP ranges

## Next Steps

After completing this configuration:

1. **Test Integration**: Create ExternalSecret resources and verify ESO can sync secrets from Vault
2. **Update Documentation**: Document your specific configuration for your team
3. **Implement Monitoring**: Set up alerts for Vault authentication failures and ESO sync issues
4. **Plan Secret Rotation**: Schedule regular secret rotation procedures

For more information, see:

- [External Secrets Operator Documentation](https://external-secrets.io/)
- [Vault KV Secrets Engine](https://www.vaultproject.io/docs/secrets/kv)
- [Vault Kubernetes Auth Method](https://www.vaultproject.io/docs/auth/kubernetes)