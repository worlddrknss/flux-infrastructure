
HashiCorp Vault + SOPS Integration Guide for Flux
===================================================

> **Note**: This is a rough, preliminary draft and may require refinement for production use.

Purpose
-------

This document provides a comprehensive guide for configuring HashiCorp Vault to work with SOPS (Secrets OPerationS) and Flux for secure secret management in Kubernetes. By the end of this guide, you'll have a fully configured Vault instance that can encrypt and decrypt secrets for your Flux-managed GitOps workflows.

## Overview

This integration enables:
- **Encrypted secrets at rest** in your Git repositories using SOPS
- **Runtime decryption** via Vault's Transit secrets engine
- **Secure authentication** between Flux controllers and Vault using Kubernetes auth
- **Audit trail** of all secret access through Vault logs

## TL;DR

1. Enable Vault's Transit secrets engine and create a `sops` key
2. Create a minimal ACL policy allowing encrypt/decrypt operations
3. Configure Kubernetes authentication in Vault
4. Bind Flux service accounts to a Vault role with the appropriate policy

Prerequisites
-------------

Before beginning this configuration, ensure you have:

- **Vault Server**: A running HashiCorp Vault instance accessible via UI/API (e.g., `http://<vault-node-ip>:8200/ui`)
- **Vault Access**: Admin-level token or root access to configure auth methods and policies  
- **Kubernetes Cluster**: Access to the cluster where Flux is installed with permissions to manage service accounts in the `flux-system` namespace
- **Flux Installation**: A working Flux installation in your cluster
- **Tools** (optional): `vault` CLI and `jq` for automation scripts and verification

## Variables and Placeholders

Throughout this guide, replace these placeholders with your actual values:

- `<vault-node-ip>` — IP address or hostname of your Vault server
- `<token-reviewer-jwt>` — JWT token used by Vault to validate Kubernetes service accounts
- `flux-system` — Namespace where Flux controllers run (adjust if different)

Implementation Steps
--------------------

### Step 1: Access Vault UI

1. Open your browser and navigate to the Vault UI: `http://<vault-node-ip>:8200/ui`
2. Authenticate using your admin token (typically `root` or another administrative token)

### Step 2: Enable Transit Secrets Engine

1. In the left navigation panel, click **Secrets Engines**
2. Click **Enable new engine** 
3. Select **Transit** from the list of available engines
4. Keep the default path as `transit` and click **Enable Engine**

### Step 3: Create Transit Key for SOPS

1. Navigate into the newly created Transit engine
2. Click **Create key**
3. Set the key name to: `sops`
4. Leave the key type as the default `AES256-GCM96`
5. Click **Create**

You should now see the `sops` key listed in your Transit keys.

### Step 4: Create Vault Policy for Flux

1. Navigate to **Access** → **Policies** → **Create ACL Policy**
2. Set the policy name to: `flux-sops-policy`
3. Enter the following policy content:

```hcl
path "transit/encrypt/sops" {
  capabilities = ["update"]
}
path "transit/decrypt/sops" {
  capabilities = ["update"]
}
```

4. Click **Create policy** to save

This policy grants Flux controllers the minimal permissions needed to encrypt and decrypt using the `sops` transit key.

### Step 5: Enable Kubernetes Authentication

1. Navigate to **Access** → **Auth Methods**
2. Click **Enable new method** and select **Kubernetes**
3. Keep the default path as `kubernetes` and click **Enable Method**

### Step 6: Configure Kubernetes Authentication

1. Click into the newly enabled `kubernetes` auth method
2. Go to **Configuration** and provide the following details:
   - **Kubernetes Host**: `https://kubernetes.default.svc.cluster.local`
   - **CA Certificate**: Paste the contents from `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`
   - **Token Reviewer JWT**: Paste the JWT token for a service account with TokenReview permissions
3. Click **Save** to store the configuration

### Step 7: Create Vault Role for Flux Controllers

1. While still in the `kubernetes` auth method, navigate to **Roles** → **Create Role**
2. Configure the role with these settings:
   - **Role name**: `flux-sops-role`
   - **Bound service account names**: `source-controller,kustomize-controller` (or specific controllers that need access)
   - **Bound service account namespaces**: `flux-system`
   - **Generated token's policies**: `flux-sops-policy`
   - **Generated token's TTL**: `24h` (or as appropriate for your security requirements)
3. Click **Create role** to save

## CLI Alternative

For automation or script-based deployment, use these Vault CLI commands instead of the UI:

```bash
# Ensure you're authenticated to Vault
export VAULT_ADDR="http://<vault-node-ip>:8200"
export VAULT_TOKEN="<your-admin-token>"

# Enable the Transit secrets engine
vault secrets enable transit

# Create the SOPS encryption key
vault write -f transit/keys/sops

# Create the policy for Flux controllers
cat <<'EOF' | vault policy write flux-sops-policy -
path "transit/encrypt/sops" {
  capabilities = ["update"]
}
path "transit/decrypt/sops" {
  capabilities = ["update"]
}
EOF

# Enable Kubernetes authentication
vault auth enable kubernetes

# Configure Kubernetes authentication
# Note: Obtain the actual CA certificate and reviewer token from your cluster
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt="<token-reviewer-jwt>"

# Create the Vault role for Flux
vault write auth/kubernetes/role/flux-sops-role \
  bound_service_account_names=source-controller,kustomize-controller \
  bound_service_account_namespaces=flux-system \
  policies=flux-sops-policy \
  ttl=24h
```

## Verification

### Testing the Transit Key

Verify that your transit key is working correctly:

```bash
# Test encryption
echo -n "test-secret-data" | base64 | \
  vault write -format=json transit/encrypt/sops plaintext=- | \
  jq -r '.data.ciphertext'

# Save ciphertext for decryption test
CIPHERTEXT=$(echo -n "test-secret-data" | base64 | \
  vault write -format=json transit/encrypt/sops plaintext=- | \
  jq -r '.data.ciphertext')

# Test decryption
vault write -format=json transit/decrypt/sops ciphertext="$CIPHERTEXT" | \
  jq -r '.data.plaintext' | base64 -d
```

### Verifying Kubernetes Auth

Test that Flux service accounts can authenticate:

```bash
# Get a service account token (example for source-controller)
SA_TOKEN=$(kubectl get secret -n flux-system \
  $(kubectl get sa source-controller -n flux-system -o jsonpath='{.secrets[0].name}') \
  -o jsonpath='{.data.token}' | base64 -d)

# Test authentication
vault write auth/kubernetes/login \
  role=flux-sops-role \
  jwt="$SA_TOKEN"
```

## Troubleshooting

### Common Issues

**Flux cannot decrypt SOPS-encrypted files:**

- Verify the Vault policy paths are correct (must use `transit/encrypt/sops` and `transit/decrypt/sops`)
- Check that the Vault role is bound to the correct service account names and namespace
- Ensure the Kubernetes auth configuration has the correct cluster CA certificate and token reviewer JWT
- Review Vault audit logs for authentication or authorization failures

**Authentication failures:**

- Confirm the service account exists in the specified namespace
- Verify the service account has the necessary RBAC permissions
- Check that the bound service account names in the Vault role match exactly

**Policy issues:**

- Ensure the policy name is referenced correctly in the Vault role
- Verify the transit key name matches exactly (`sops`)
- Check that capabilities include `["update"]` for both encrypt and decrypt paths

### Debug Commands

```bash
# Check Vault status
vault status

# List enabled auth methods
vault auth list

# Check if transit engine is enabled
vault secrets list

# View policy details
vault policy read flux-sops-policy

# List roles for kubernetes auth
vault list auth/kubernetes/role
```

## Security Considerations

### Access Control

- **Principle of Least Privilege**: The provided policy grants only the minimum permissions required for SOPS operations
- **Service Account Binding**: Roles are bound to specific service accounts in specific namespaces
- **Token TTL**: Configure appropriate token lifetimes based on your security requirements

### Monitoring and Auditing

- **Enable Vault Auditing**: Configure audit logging to track all secret access
- **Monitor Failed Attempts**: Set up alerting for authentication and authorization failures  
- **Regular Access Reviews**: Periodically review and rotate service account tokens

### Key Management

- **Key Rotation**: Plan for regular rotation of the `sops` transit key
- **Backup Strategy**: Ensure Vault backups include transit keys for disaster recovery
- **Multi-Region**: Consider Vault clustering for high availability scenarios

### Network Security

- **TLS Encryption**: Always use HTTPS/TLS for Vault communication in production
- **Network Policies**: Restrict network access to Vault using Kubernetes Network Policies
- **Firewall Rules**: Limit Vault access to necessary ports and IP ranges

## Next Steps

After completing this configuration:

1. **Test Integration**: Create a test secret encrypted with SOPS and verify Flux can decrypt it
2. **Update Documentation**: Document your specific configuration for your team
3. **Implement Monitoring**: Set up alerts for Vault authentication failures
4. **Plan Rotation**: Schedule regular key and token rotation procedures

For more information, see:

- [SOPS Documentation](https://github.com/mozilla/sops)
- [Flux SOPS Guide](https://fluxcd.io/docs/guides/mozilla-sops/)
- [Vault Transit Secrets Engine](https://www.vaultproject.io/docs/secrets/transit)