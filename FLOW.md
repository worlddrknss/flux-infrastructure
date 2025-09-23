

# GitLab CI — Terraform Pipeline (Enterprise Overview)

[![GitLab CI](https://img.shields.io/badge/GitLab-CI-blue.svg)](https://docs.gitlab.com/ee/ci/)

> Enterprise-grade documentation of the Terraform pipeline implemented in `.gitlab-ci.yml`.

## Table of Contents

- [GitLab CI — Terraform Pipeline (Enterprise Overview)](#gitlab-ci--terraform-pipeline-enterprise-overview)
  - [Table of Contents](#table-of-contents)
  - [Executive Summary](#executive-summary)
  - [Pipeline Architecture \& Flow](#pipeline-architecture--flow)
  - [Pipeline Stages](#pipeline-stages)
  - [Required CI Variables \& Secrets](#required-ci-variables--secrets)
  - [Job Template: `.terraform-job`](#job-template-terraform-job)
  - [Job Reference](#job-reference)
  - [Runbook](#runbook)
    - [Operational Steps](#operational-steps)
  - [Security \& Compliance Notes](#security--compliance-notes)
  - [Troubleshooting](#troubleshooting)
  - [Ownership \& Contact](#ownership--contact)
  - [Change Log](#change-log)

## Executive Summary

This repository contains an automated Terraform workflow executed by GitLab CI. The pipeline is designed for secure, auditable infrastructure changes using OIDC-based AWS role assumption and a centralized S3/DynamoDB backend for state and locking.

Goals:

- Enforce Terraform formatting and validation before planning
- Produce an auditable plan artifact for manual approval
- Gate destructive or mutating operations behind manual approval steps
- Integrate SAST and secret detection templates for CI security scanning

Intended audience: Platform engineers, security engineers, SREs, and release approvers.

## Pipeline Architecture & Flow

High-level flow:

1. On changes to `scripts/terraform/**/*` on the `main` branch, GitLab runs `validate` → `plan`.
2. `plan` outputs a binary plan artifact stored as a job artifact.
3. `apply` (manual) consumes the plan artifact and runs `terraform apply`.
4. `destroy` (manual) performs an explicit destroy action when required.

ASCII Diagram

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

- test — static analysis and SAST (included templates)
- secret-detection — secret scanning (included template)
- validate — terraform fmt & validate
- plan — terraform plan (produces artifact)
- apply — terraform apply (manual)
- destroy — terraform destroy (manual)

Jobs are scoped by `rules` to run only for `main` and when Terraform files change under `scripts/terraform/**/*`.

## Required CI Variables & Secrets

The pipeline expects the following CI/CD variables to be defined (project or group level). Treat secrets with `masked/protected` flags as appropriate.

| Variable | Purpose | Recommended protection |
|---|---:|---|
| TF_ROOT | Relative path where Terraform commands run (default: `scripts/terraform`) | non-sensitive |
| TF_STATE_KEY | Backend key for state file (dynamic) | non-sensitive |
| TF_STATE_BUCKET | S3 bucket for Terraform state | protected |
| TF_STATE_REGION | AWS region for state backend | non-sensitive |
| TF_STATE_LOCK_TABLE | DynamoDB table for state locking | protected |
| AWS_ROLE_ARN | IAM Role ARN assumed via OIDC | protected, masked |
| GITLAB_OIDC_TOKEN | GitLab injected ID token (provided via id_tokens) | injected at runtime |

Operational note: Do not store long-lived AWS credentials in CI. The pipeline uses GitLab OIDC + AssumeRoleWithWebIdentity to obtain ephemeral credentials.

## Job Template: `.terraform-job`

Purpose: centralizes setup and authentication for Terraform jobs.

Key behaviors:

- Uses image: `hashicorp/terraform:1.13.0`
- Installs AWS CLI (`apk add --no-cache aws-cli`) in the container
- Exchanges the GitLab OIDC ID token for temporary AWS credentials via `aws sts assume-role-with-web-identity`
- Exports `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN`
- Runs `terraform init` with backend-config parameters for S3 + DynamoDB lock table

Security note: `id_tokens.GITLAB_OIDC_TOKEN` must be allowed by the IAM trust policy for the target `AWS_ROLE_ARN`. The GitLab `aud` claim is configured as `https://gitlab.com`.

## Job Reference

validate (stage: validate)

- Extends: `.terraform-job`
- Commands:
  - `terraform fmt -recursive`
  - `terraform validate`
- Trigger: runs on `main` when Terraform files change
- Purpose: catch syntax/formatting issues early

plan (stage: plan)

- Extends: `.terraform-job`
- Commands: `terraform plan -out=tfplan`
- Artifacts: `scripts/terraform/tfplan` (expires 1 hour)
- Depends on: `validate`
- Purpose: produce a binary plan for review and apply

apply (stage: apply) — manual approval required

- Extends: `.terraform-job`
- Commands: `terraform apply -auto-approve tfplan`
- Consumes: `tfplan` artifact from `plan` job
- When: `manual` (only appears when changes detected)
- Purpose: apply reviewed infrastructure changes

destroy (stage: destroy) — manual approval required

- Extends: `.terraform-job`
- Commands: `terraform destroy -auto-approve`
- When: `manual`
- Purpose: explicit, deliberate infrastructure teardown

## Runbook

### Operational Steps

Pre-flight (before clicking Apply):

1. Confirm preconditions: CI variables present (`TF_STATE_BUCKET`, `TF_STATE_LOCK_TABLE`, `AWS_ROLE_ARN`).
2. Review the generated plan: download `tfplan` artifact from the `plan` job and run `terraform show tfplan` locally or in a controlled environment.
3. Verify `aws sts get-caller-identity` output in the job logs to ensure role assumption succeeded.

Execute Apply (manual):

1. In the GitLab pipeline UI, validate the `plan` job output and artifacts.
2. Trigger `apply` manually and monitor logs for `terraform apply` progress.
3. Post-apply verification: run smoke checks (cluster readiness, key resource statuses).

Rollback / Destroy:

- If changes cause incidents, create a short-lived rollback plan (revert the Git commit that caused the change and re-run pipeline), or execute `destroy` manually only after approval and cross-team alignment.

## Security & Compliance Notes

- SAST and IaC SAST templates are included to scan code and IaC for known issues.
- Secret detection template is included to surface accidental secrets in commits.
- Artifact retention for `tfplan` is short (1 hour) to reduce exposure of plan details; extend only with a documented justification.
- IAM Trust: ensure the IAM role's trust policy restricts which GitLab projects/branches/subjects can assume it.

## Troubleshooting

- Terraform init failures: verify backend variables (`TF_STATE_BUCKET`, `TF_STATE_REGION`, `TF_STATE_LOCK_TABLE`) and that the assumed role has S3/DynamoDB permissions.
- Assume role failures: check the IAM trust relationship and that the incoming `aud` claim matches `https://gitlab.com` as configured.
- Artifact missing in apply: confirm `plan` produced `tfplan` and artifact retention did not expire before manual apply.

## Ownership & Contact


- Platform team: <mailto:platform-ops@example.com>
- Security lead: <mailto:security@example.com>
- On-call: Refer to the SRE rota (PagerDuty)

## Change Log

- 2025-09-23 — Enterprise-style rewrite and runbook added
