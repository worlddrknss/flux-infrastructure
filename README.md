
# FluxCD & DevSecOps Demo Repository

## Overview

This repository is an enterprise demo of GitOps workflows using [FluxCD](https://fluxcd.io/) and DevSecOps best practices, deployed on a [k3s](https://k3s.io/) Kubernetes cluster. It provides a reference architecture for secure, automated, and scalable management of Kubernetes infrastructure and applications.

## Key Features

- **GitOps with FluxCD:** Declarative infrastructure and application management using Git as the source of truth.
- **DevSecOps Integration:** Security is embedded throughout the CI/CD pipeline, including automated policy enforcement and secrets management.
- **Modular Structure:** Organized for multi-cluster, multi-environment deployments with reusable components.
- **Enterprise-Ready:** Demonstrates patterns suitable for regulated, large-scale organizations.
- **K3s-based Demo:** All manifests and configurations are designed for k3s, a lightweight Kubernetes distribution ideal for edge and development environments.

## Repository Structure

- `clusters/` — Environment-specific configurations and manifests for Kubernetes clusters.
	- `default/` — Example cluster setup, including Flux system, ingress, and security integrations.
		- `flux-system/` — Core FluxCD components and sync configuration.
		- `hashicorp/vault/` — Secrets management integration using HashiCorp Vault.
		- `ingress-nginx/` — Ingress controller setup for secure traffic management.
		- `kube-system/cilium/` — Network security and observability with Cilium ([k3s install guide](https://docs.cilium.io/en/stable/installation/k3s)).

## Getting Started

1. **Clone the repository:**

	```pwsh
	git clone https://gitlab.com/worlddrknss/flux-infrastructure.git
	```

2. **Review the cluster manifests** in `clusters/default/` for deployment examples.

3. **Apply manifests** to your k3s Kubernetes cluster using FluxCD.

4. **Cilium on k3s:**
			- For installing Cilium on k3s, refer to the official guide: [Cilium k3s Installation](https://docs.cilium.io/en/stable/installation/k3s)

## About FluxCD

FluxCD is a CNCF graduated project that enables GitOps for Kubernetes, automating deployment, monitoring, and management of applications and infrastructure.

## About DevSecOps

DevSecOps integrates security practices into DevOps workflows, ensuring that security is a shared responsibility throughout the software development lifecycle.

## Disclaimer

This repository is for demonstration purposes only. It is not intended for production use without further customization and security review.
