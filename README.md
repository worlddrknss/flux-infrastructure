

# FluxCD & DevSecOps Demo Repository

## Overview

This repository demonstrates GitOps workflows using FluxCD and DevSecOps patterns for a k3s Kubernetes cluster. It is intended as a reference architecture for teams learning how to manage infrastructure and applications declaratively with Flux.

This README was updated to reflect the repository layout as of the current branch and to provide clearer local bootstrapping and troubleshooting notes.

## What's changed

- Reorganized manifests under `clusters/default/` and `apps/` to separate cluster-level infrastructure from application overlays.
- Added example controllers and configs in `infrastructure/` (Cilium, Vault, ingress-nginx).
- The Flux manifests live under `clusters/default/flux-system/` and are intended to be the system that reconciles the rest of the repo.

## Key Features

- GitOps with FluxCD: declarative infrastructure and application management using Git as the source of truth.
- DevSecOps patterns: demonstrates integration points for secrets management (Vault), network security (Cilium), and ingress controls.
- Modular structure: `clusters/`, `infrastructure/`, and `apps/` split responsibilities for clarity and reuse.

## Repository layout (important paths)

- `clusters/default/` — cluster-specific manifests including Flux system Kustomize overlays and cluster bootstrap definitions.
- `clusters/default/flux-system/` — Flux components and sync Kustomizations (`gotk-components.yaml`, `gotk-sync.yaml`, `kustomization.yaml`).
- `infrastructure/` — controllers and infrastructure-related manifests (e.g. `cilium.yaml`, `hashicorp-vault.yaml`, `ingress-nginx.yaml`) and `configs/` for controller configuration.
- `apps/` — application overlays and releases (examples: `podinfo/`, `wordpress/`).

## Getting started (local / demo)

The steps below assume you have a k3s cluster available and `kubectl` configured to talk to it.

1. Clone the repository:

```bash
git clone https://gitlab.com/worlddrknss/flux-infrastructure.git
cd flux-infrastructure
```



1. (Optional) Review manifests in `clusters/default/` and `apps/` and adapt any `namespace`, `release`, or `repository` references to your environment.

1. Bootstrap Flux on your cluster (example using the `flux` CLI):

```bash
# install the flux CLI if you don't have it: https://fluxcd.io/docs/installation/#install-the-flux-cli
# bootstrap using your repo (replace URL and branch as needed):
flux bootstrap git \
  --url=git@gitlab.com:worlddrknss/flux-infrastructure.git \
  --branch=main \
  --path=clusters/default \
  --private-key-file=~/.ssh/id_rsa
```

If you prefer to manually apply the Flux manifests already present in the repo, apply the `flux-system` kustomization found at `clusters/default/flux-system/`:

```bash
kubectl apply -k clusters/default/flux-system
```



1. Once the Flux system is running, it will reconcile the Kustomizations defined under `clusters/default` and `apps`. Use `flux` and `kubectl` to inspect status:

```bash
flux get kustomizations --all-namespaces
kubectl get pods -n flux-system
```

## Cilium (k3s) and other controllers

This repo includes manifests and config snippets for Cilium, HashiCorp Vault, and nginx ingress. For production or non-demo clusters, follow the official installation guides and adapt the YAML files in `infrastructure/` and `infrastructure/configs/`.

Cilium k3s install guide: [https://docs.cilium.io/en/stable/installation/k3s](https://docs.cilium.io/en/stable/installation/k3s)

## Troubleshooting & notes

- If Flux fails to reconcile, check `kubectl -n flux-system logs deploy/source-controller` and `kubectl -n flux-system get events` for errors.
- If private repositories are used for Helm/OCI or git, ensure your credentials (SSH keys, tokens) are configured in the cluster (Secrets) and referenced in the Flux `GitRepository` objects.
- Namespace mismatches are a common source of problems: confirm `namespace` fields in `apps/` and `clusters/` match the namespaces present in the cluster or are created by Flux.

## About FluxCD and DevSecOps

FluxCD automates deployment, monitoring, and management of Kubernetes workloads using Git as the single source of truth. DevSecOps practices (secrets scanning, policy enforcement, least-privilege service accounts) should be applied before promoting this demo to production.

## Disclaimer

This repository is a demonstration and learning reference. It is not production-ready and needs additional hardening (RBAC, secrets management, network policies, and image signing) for real deployments.

## Secrets Management: External Secrets Operator + HashiCorp Vault

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

