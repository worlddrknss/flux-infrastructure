

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

## Work in progress: SOPS + HashiCorp Vault integration

Goal: enable encrypted secrets management for manifests and Helm values using Mozilla SOPS, with keys managed by HashiCorp Vault (Transit secret engine), and automated decryption in-cluster via a SOPS controller or external decryptor used by Flux.

Planned approach and components:

- Use `sops` to encrypt YAML manifests and Helm value files in the repo. Encryption keys will be provided by a Vault Transit key (or Vault-managed PGP/age keys depending on final approach).
- Configure Vault (HashiCorp Vault) to host the encryption key(s) and enable the `transit` secret engine for envelope encryption.
- Run a decryption agent in-cluster (examples: Flux's `sops-controller` or an init sidecar) that can fetch keys from Vault and decrypt resources for Flux before apply.
- Store Vault credentials in Kubernetes as tightly-scoped ServiceAccounts + Vault Agent or Kubernetes auth method with least privilege.

Example `.sops.yaml` (repository root) — instructs `sops` which keys to use (example using a Vault transit key):

```yaml
creation_rules:
  - path_regex: ".*\\.(yaml|yml)$"
    encrypted_regex: "^(data|stringData)$"
    key_groups:
      - pgp: []
    vault_transit:
      - name: "flux-sops-transit"
        address: "https://vault.example.local:8200"
        token: "<use-automation-to-store-token>"
```

Notes: the `vault_transit` example above is illustrative — `sops` supports `pgp`, `age`, and `kms` backends natively; using Vault's transit engine is typically done through community integrations or by using Vault to generate wrapped keys.

Flux + SOPS integration patterns to consider:

- sops-controller: a Kubernetes controller that can watch SOPS-encrypted secrets and produce decrypted Secrets (requires RBAC and Vault connectivity).
- External decryption: CI or a sidecar/agent that decrypts files and writes them to a location Flux reads (or to a GitRepository/OCI registry Flux can read from).
- Use `age` keys sealed in Vault and export public keys to `sops` configs — simplifies local developer workflows while Vault holds private material.

Security considerations:

- Do not commit Vault tokens or private keys to the repo. Use wrapped tokens, Kubernetes auth roles, or Vault Agent to authenticate.
- Use least-privilege Vault policies scoped to only the transit/encrypt-decrypt operations required by Flux or the controller.
- Rotate Transit keys periodically and have a migration/reencryption plan for repository secrets.

Next steps (implementation plan):

1. Prototype using `sops` + a Vault dev instance to encrypt/decrypt a single secret manifest.
2. Evaluate `sops-controller` (or similar) for in-cluster decryption and test RBAC/Vault auth flows.
3. Add example manifests and a `clusters/default` Kustomize overlay showing how encrypted secrets will be stored and referenced.
4. Document operational steps for key rotation, token renewal, and troubleshooting.

If you'd like, I can:

- Add a working example `sops`-encrypted secret and a corresponding `sops` config in the repo.
- Create a `scripts/` helper to encrypt/decrypt files with `sops` against a test Vault instance.
- Draft Vault policies and example Kubernetes auth setup for the in-cluster service account.

