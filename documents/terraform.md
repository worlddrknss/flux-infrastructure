

# GitLab CI — Terraform Pipeline

[![GitLab CI](https://img.shields.io/badge/GitLab-CI-blue.svg)](https://docs.gitlab.com/ee/ci/)
[![Terraform](https://img.shields.io/badge/Terraform-1.13+-purple.svg)](https://www.terraform.io/)

> Operational documentation for the Terraform pipeline implemented in `.gitlab-ci.yml`.

## Table of Contents

- [GitLab CI — Terraform Pipeline](#gitlab-ci--terraform-pipeline)
  - [Table of Contents](#table-of-contents)
  - [Executive Summary](#executive-summary)
  - [Pipeline Architecture \& Flow](#pipeline-architecture--flow)
  - [Pipeline Stages](#pipeline-stages)
  - [Required CI Variables \& Secrets](#required-ci-variables--secrets)
  - [Job Template: `.terraform-job`](#job-template-terraform-job)
  - [Job Reference](#job-reference)
    - [validate (stage: validate)](#validate-stage-validate)
    - [plan (stage: plan)](#plan-stage-plan)
    - [apply (stage: apply) — manual approval required](#apply-stage-apply--manual-approval-required)
    - [destroy (stage: destroy) — manual approval required](#destroy-stage-destroy--manual-approval-required)
  - [Runbook](#runbook)
    - [Pre-flight Checks](#pre-flight-checks)
    - [Execute Apply](#execute-apply)
    - [Rollback / Destroy](#rollback--destroy)
  - [Security \& Compliance Notes](#security--compliance-notes)
  - [Troubleshooting](#troubleshooting)
  - [Ownership \& Contact](#ownership--contact)
  - [Change Log](#change-log)

## Executive Summary

This repository contains an automated Terraform workflow executed by GitLab CI. The pipeline provides secure, auditable infrastructure changes using OIDC-based AWS role assumption and a centralized S3 backend with file-based locking.

**Key Features:**

- Enforces Terraform formatting and validation before planning
- Produces auditable plan artifacts for manual approval
- Gates destructive operations behind manual approval steps
- Integrates SAST and secret detection for security scanning

**Audience:** Platform engineers, security engineers, SREs, and release approvers.

## Pipeline Architecture & Flow

**Workflow:**

1. On changes to `scripts/terraform/**/*` on the `main` branch, GitLab runs `validate` → `plan`.
2. `plan` outputs a binary plan artifact stored as a job artifact.
3. `apply` (manual) consumes the plan artifact and runs `terraform apply`.
4. `destroy` (manual) performs explicit destroy actions when required.

**Pipeline Flow:**

```text
   Git Push (main, scripts/terraform/**)
               |
           [validate]
               |
           [plan] -> artifact: tfplan
               |
     (manual) [apply]  <-- requires approval, consumes artifact
               |
     (manual) [destroy] <-- manual-only, gated
```

## Pipeline Stages

- **test** — static analysis and SAST (included templates)
- **secret-detection** — secret scanning (included template)
- **validate** — terraform fmt & validate
- **plan** — terraform plan (produces artifact)
- **apply** — terraform apply (manual)
- **destroy** — terraform destroy (manual)

Jobs are scoped by `rules` to run only on `main` when Terraform files change under `scripts/terraform/**/*`.

## Required CI Variables & Secrets

The pipeline requires the following CI/CD variables to be configured in GitLab (project or group level):

| Variable | Purpose | Protection |
|---|---|---|
| AWS_ROLE_ARN | IAM Role ARN assumed via OIDC | protected, masked |
| TF_STATE_BUCKET | S3 bucket for Terraform state | protected, masked |
| TF_STATE_REGION | AWS region for state backend | protected, masked |

**Additional variables (defined in pipeline):**

- `TF_ROOT` — Set to `scripts/terraform` (working directory)
- `TF_STATE_KEY` — Dynamic key: `env/${CI_PROJECT_NAME}/${CI_COMMIT_REF_SLUG}/${CI_PROJECT_NAME}.tfstate`
- `GITLAB_OIDC_TOKEN` — Automatically injected by GitLab via `id_tokens`

**Note:** The pipeline uses GitLab OIDC + AssumeRoleWithWebIdentity for secure, temporary AWS credentials. No long-lived AWS keys are stored in CI.

## Job Template: `.terraform-job`

Centralizes setup and authentication for all Terraform jobs.

**Key behaviors:**

- Uses Docker image: `hashicorp/terraform:1.13.0`
- Installs AWS CLI (`apk add --no-cache aws-cli`)
- Exchanges GitLab OIDC ID token for temporary AWS credentials via `aws sts assume-role-with-web-identity`
- Exports `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN`
- Runs `terraform init` with S3 backend configuration using file-based locking (`use_lockfile`)

**Security requirement:** `id_tokens.GITLAB_OIDC_TOKEN` must be allowed by the IAM trust policy for `AWS_ROLE_ARN`. The GitLab `aud` claim is configured as `https://gitlab.com`.

## Job Reference

### validate (stage: validate)

- **Extends:** `.terraform-job`
- **Commands:** `terraform fmt -recursive`, `terraform validate`
- **Trigger:** runs on `main` when Terraform files change
- **Purpose:** catch syntax/formatting issues early

### plan (stage: plan)

- **Extends:** `.terraform-job`
- **Commands:** `terraform plan -out=tfplan`
- **Artifacts:** `scripts/terraform/tfplan` (expires 1 hour)
- **Depends on:** `validate`
- **Purpose:** produce a binary plan for review and apply

### apply (stage: apply) — manual approval required

- **Extends:** `.terraform-job`
- **Commands:** `terraform apply -auto-approve tfplan`
- **Consumes:** `tfplan` artifact from `plan` job
- **When:** `manual` (only appears when changes detected)
- **Purpose:** apply reviewed infrastructure changes

### destroy (stage: destroy) — manual approval required

- **Extends:** `.terraform-job`
- **Commands:** `terraform destroy -auto-approve`
- **When:** `manual`
- **Purpose:** explicit, deliberate infrastructure teardown

## Runbook

### Pre-flight Checks

Before triggering `apply`:

1. **Verify CI variables:** Confirm `AWS_ROLE_ARN`, `TF_STATE_BUCKET`, `TF_STATE_REGION` are configured
2. **Review plan:** Download `tfplan` artifact and run `terraform show tfplan` locally
3. **Confirm authentication:** Verify `aws sts get-caller-identity` output in job logs

### Execute Apply

1. Validate the `plan` job output and artifacts in GitLab pipeline UI
2. Trigger `apply` manually and monitor logs for `terraform apply` progress
3. **Post-apply verification:** Run smoke checks (cluster readiness, key resource statuses)

### Rollback / Destroy

- **For incidents:** Revert the Git commit that caused the change and re-run pipeline
- **For teardown:** Execute `destroy` manually only after approval and cross-team alignment

## Security & Compliance Notes

- **SAST scanning:** Includes templates for static analysis and IaC security scanning
- **Secret detection:** Automatically scans commits for exposed secrets
- **Artifact retention:** `tfplan` expires after 1 hour to limit exposure
- **IAM trust policy:** Ensure the role restricts access to authorized GitLab projects/branches

## Troubleshooting

- **Terraform init failures:** Verify backend variables and S3 permissions for assumed role
- **Role assumption failures:** Check IAM trust policy and `aud` claim configuration (`https://gitlab.com`)
- **Missing artifacts:** Confirm `plan` job completed successfully and artifact hasn't expired
- **State locking issues:** Terraform uses file-based locking with S3; check for stale `.terraform.lock.hcl` files

## Ownership & Contact

- **Platform team:** <mailto:platform-ops@example.com>
- **Security lead:** <mailto:security@example.com>
- **On-call:** Refer to SRE rotation (PagerDuty)

## Change Log

- **2025-09-23** — Documentation cleanup and restructuring
