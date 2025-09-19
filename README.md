

# FluxCD & DevSecOps Demo Repository

> **Note**: This is a demonstration repository for learning purposes and requires additional hardening for production use.

## Overview

This repository demonstrates GitOps workflows using FluxCD and DevSecOps patterns for a k3s Kubernetes cluster. It serves as a reference architecture for teams learning how to manage infrastructure and applications declaratively with Flux.

This README reflects the current repository layout and provides clear local bootstrapping and troubleshooting guidance.

## What's Changed

- **Repository Structure**: Reorganized manifests under `clusters/default/` and `apps/` to separate cluster-level infrastructure from application overlays
- **Infrastructure Components**: Added example controllers and configs in `infrastructure/` (Cilium, Vault, ingress-nginx)
- **Flux Bootstrap**: Flux manifests live under `clusters/default/flux-system/` and reconcile the rest of the repository

## Key Features

- **GitOps with FluxCD**: Declarative infrastructure and application management using Git as the source of truth
- **DevSecOps Patterns**: Demonstrates integration points for secrets management (Vault), network security (Cilium), and ingress controls
- **Modular Structure**: `clusters/`, `infrastructure/`, and `apps/` directories split responsibilities for clarity and reuse
- **Production-Ready Examples**: Includes real-world configurations for common Kubernetes controllers and applications

## Repository Layout (Important Paths)

- **`clusters/default/`** — Cluster-specific manifests including Flux system Kustomize overlays and cluster bootstrap definitions
- **`clusters/default/flux-system/`** — Flux components and sync Kustomizations (`gotk-components.yaml`, `gotk-sync.yaml`, `kustomization.yaml`)
- **`infrastructure/`** — Controllers and infrastructure-related manifests (e.g., `cilium.yaml`, `hashicorp-vault.yaml`, `ingress-nginx.yaml`) and `configs/` for controller configuration
- **`apps/`** — Application overlays and releases (examples: `podinfo/`, `wordpress/`)

## Prerequisites

Before getting started, ensure you have:

- **Kubernetes Cluster**: A running k3s cluster with `kubectl` configured
- **Git Access**: SSH key configured for GitLab access (if using private repositories)
- **Flux CLI**: Install from [FluxCD installation guide](https://fluxcd.io/docs/installation/#install-the-flux-cli)

## Getting Started (Local / Demo)

The steps below assume you have a k3s cluster available and `kubectl` configured to communicate with it.

1. **Clone the repository:**

   ```bash
   git clone https://gitlab.com/worlddrknss/flux-infrastructure.git
   cd flux-infrastructure
   ```

2. **Review and customize manifests (optional):**

   Review manifests in `clusters/default/` and `apps/` and adapt any `namespace`, `release`, or `repository` references to your environment.

3. **Bootstrap Flux on your cluster:**

   Using the `flux` CLI (recommended):

   ```bash
   # Install the flux CLI if you don't have it: https://fluxcd.io/docs/installation/#install-the-flux-cli
   # Bootstrap using your repo (replace URL and branch as needed):
   flux bootstrap git \
     --url=git@gitlab.com:worlddrknss/flux-infrastructure.git \
     --branch=main \
     --path=clusters/default \
     --private-key-file=~/.ssh/id_rsa
   ```

   Alternatively, manually apply the Flux manifests already present in the repository:

   ```bash
   kubectl apply -k clusters/default/flux-system
   ```

4. **Verify Flux installation:**

   Once the Flux system is running, it will reconcile the Kustomizations defined under `clusters/default` and `apps`. Use `flux` and `kubectl` to inspect status:

   ```bash
   flux get kustomizations --all-namespaces
   kubectl get pods -n flux-system
   ```

## Infrastructure Controllers

This repository includes manifests and configuration examples for common Kubernetes controllers:

### Cilium (CNI and Network Security)

- **Purpose**: Container Network Interface (CNI) with advanced network security features
- **Configuration**: See `infrastructure/controllers/cilium.yaml` and `infrastructure/configs/cilium-config.yaml`
- **k3s Integration**: Follow the [Cilium k3s installation guide](https://docs.cilium.io/en/stable/installation/k3s) for production deployments

### HashiCorp Vault

- **Purpose**: Secrets management and encryption services
- **Configuration**: See `infrastructure/controllers/hashicorp-vault.yaml`
- **SecretStore Config**: See `infrastructure/configs/vault-secretstore.yaml`
- **Integration Guides**:
  - `README-VAULT-SOPS.md` — Vault + SOPS configuration for GitOps secret encryption
  - `README-VAULT-ESO.md` — Vault + External Secrets Operator setup

### External Secrets Operator

- **Purpose**: Synchronizes secrets from external systems (like Vault) to Kubernetes Secret resources
- **Configuration**: See `infrastructure/controllers/external-secrets.yaml`
- **SecretStore Integration**: Works with Vault via `infrastructure/configs/vault-secretstore.yaml`

### Ingress NGINX

- **Purpose**: Kubernetes ingress controller for HTTP/HTTPS traffic management
- **Configuration**: See `infrastructure/controllers/ingress-nginx.yaml`

### Cert-Manager

- **Purpose**: Automated TLS certificate management for Kubernetes
- **Configuration**: See `infrastructure/controllers/cert-manager.yaml`

### Monitoring Stack

- **Prometheus**: Metrics collection and monitoring (`infrastructure/controllers/prometheus.yaml`)
- **Grafana**: Metrics visualization and dashboards (`infrastructure/controllers/grafana.yaml` and `infrastructure/configs/grafana-config.yaml`)

### Repository Sources

The following Helm repositories are configured for the above controllers:

- `infrastructure/repositories/bitnami-repo.yaml` — Bitnami Helm charts
- `infrastructure/repositories/bitnami-oci-repo.yaml` — Bitnami OCI registry
- `infrastructure/repositories/stefanprodan-repo.yaml` — Stefan Prodan's charts (podinfo, etc.)

> **Note**: For production or non-demo clusters, follow the official installation guides and adapt the YAML files in `infrastructure/` to your specific requirements.

## Troubleshooting & Common Issues

### Flux Reconciliation Failures

- **Check controller logs**: `kubectl -n flux-system logs deploy/source-controller`
- **Review events**: `kubectl -n flux-system get events`
- **Verify Git access**: Ensure SSH keys or tokens are properly configured for private repositories

### Authentication Issues

- **Private repositories**: Ensure your credentials (SSH keys, tokens) are configured in the cluster (Secrets) and referenced in the Flux `GitRepository` objects
- **Service account permissions**: Verify RBAC permissions for Flux service accounts

### Common Configuration Problems

- **Namespace mismatches**: Confirm `namespace` fields in `apps/` and `clusters/` match the namespaces present in the cluster or are created by Flux
- **Resource dependencies**: Ensure dependent resources (CRDs, namespaces) are created before dependent objects
- **Image pull failures**: Check image repository access and pull secrets configuration

### Debug Commands

```bash
# Check Flux system status
flux get all --all-namespaces

# View specific Kustomization status
kubectl get kustomizations -n flux-system

# Check source repositories
flux get sources git

# View Helm releases
flux get helmreleases --all-namespaces
```

## Security Considerations

### Production Readiness

This repository is a **demonstration and learning reference**. For production use, implement additional hardening:

- **RBAC**: Configure role-based access control with least-privilege principles
- **Network Policies**: Implement Kubernetes Network Policies to restrict pod-to-pod communication
- **Image Security**: Use signed container images and implement admission controllers
- **Secret Management**: Never commit secrets to Git; use external secret management solutions
- **Monitoring**: Implement comprehensive logging, monitoring, and alerting

### DevSecOps Best Practices

- **Secrets Scanning**: Scan repositories for accidentally committed secrets
- **Policy Enforcement**: Use tools like Open Policy Agent (OPA) Gatekeeper
- **Vulnerability Scanning**: Regularly scan container images for security vulnerabilities
- **Audit Logging**: Enable audit logging for all cluster activities

## About FluxCD and DevSecOps

FluxCD automates deployment, monitoring, and management of Kubernetes workloads using Git as the single source of truth. DevSecOps practices integrate security throughout the development lifecycle, including secrets scanning, policy enforcement, and least-privilege service accounts.

This repository demonstrates these concepts in action, providing a foundation for teams to build upon while implementing additional security measures for production environments.

## Disclaimer

This repository is a demonstration and learning reference. It is **not production-ready** and requires additional hardening (RBAC, secrets management, network policies, and image signing) for real deployments.

## Secrets Management Integration

### External Secrets Operator + HashiCorp Vault

This repository includes configuration for secure secrets management using External Secrets Operator (ESO) integrated with HashiCorp Vault. This approach provides centralized secret storage in Vault with automated synchronization to Kubernetes secrets via ESO.

### Implementation Overview

- **External Secrets Operator (ESO)**: Deployed in-cluster to sync secrets from external systems (Vault) to Kubernetes Secret resources
- **HashiCorp Vault**: Centralized secret storage using KV v2 secrets engine
- **Kubernetes Authentication**: ESO authenticates to Vault using Kubernetes service account tokens
- **Least Privilege Access**: Vault policies restrict ESO to read-only access on specific secret paths

### Key Components

- ESO watches `ExternalSecret` and `SecretStore` custom resources
- `SecretStore` defines how to connect to Vault (auth method, policies, endpoints)
- `ExternalSecret` defines which secrets to sync and where to store them in Kubernetes
- Vault Kubernetes auth method validates ESO service account tokens
- Vault KV v2 secrets engine stores application secrets

### Configuration Files

- `README-VAULT-ESO.md` — Complete setup guide for Vault + ESO integration
- `infrastructure/base/controllers/external-secrets.yaml` — ESO controller deployment
- `infrastructure/base/configs/vault-secretstore.yaml` — Vault SecretStore configuration

### Security Benefits

- **No secrets in Git**: Application secrets remain in Vault, not committed to repository
- **Centralized Management**: Single source of truth for secrets across environments  
- **Audit Trail**: All secret access logged through Vault
- **Automated Rotation**: ESO can sync updated secrets from Vault automatically
- **Least Privilege**: ESO service account limited to specific Vault paths and operations

### Next Steps

1. Review `README-VAULT-ESO.md` for detailed setup instructions
2. Configure Vault with appropriate policies and Kubernetes auth
3. Deploy ESO using the manifests in `infrastructure/`
4. Create `ExternalSecret` resources for your applications

