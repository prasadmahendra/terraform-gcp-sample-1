# Terraform CI/CD Workflows

GitHub Actions workflows for automated Terraform plan and apply across all environments.

## Workflows

### `terraform-plan.yml` — PR Plan

Runs automatically on pull requests that touch Terraform files. Posts a comment on the PR with plan results for **dev**, **prod**, and **central**.

**Trigger:** PR opened/synced/reopened against `main`

### `terraform-apply.yml` — Apply on Merge

Applies Terraform changes after merging to `main`. Behavior varies by environment:

| Environment | Trigger | Approval | Behavior |
|-------------|---------|----------|----------|
| **dev** | Auto on merge to `main` | None | Plan → Apply immediately |
| **prod** | Auto on merge to `main` | Required (GitHub Environment) | Plan → Wait for approval → Re-plan → Apply |
| **central** | Manual (`workflow_dispatch`) | Required (GitHub Environment) | Approval → Plan → Apply |

#### Dev (automatic)

- Runs whenever deployment/module/environment files change on `main`
- Uses `-detailed-exitcode` to skip apply when there are no changes
- No human intervention required

#### Prod (approval gate)

- Plan runs automatically so reviewers can see what will change
- The `apply-prod` job is gated by the **`production`** GitHub Environment
- A designated reviewer must approve the deployment from the Actions UI
- After approval, a **fresh plan** is generated before applying (guards against state drift during the approval window)

#### Central (manual only)

- Org-level resources change infrequently, so this is dispatch-only
- Also gated by the `production` environment for approval

#### Manual dispatch

All environments can be triggered manually via **Actions -> Terraform Apply -> Run workflow**, selecting the desired environment from the dropdown.

- Set **dry_run_only = true** to run auth, init, and plan only.
- With dry run enabled, all apply steps/jobs are skipped.

## Safety Features

- **Concurrency groups** per environment — no parallel applies to the same env
- **Re-plan on prod** — after approval, a new plan is created to avoid applying stale changes
- **Artifacts** — plan and apply outputs are uploaded (30-day retention) for audit
- **Detailed exit codes** — skips apply entirely when plan detects no changes

## Setup

### 1. Create the `production` GitHub Environment

1. Go to **Settings → Environments → New environment**
2. Name: `production`
3. Configure **Required reviewers** (e.g., your infra team)
4. Optional: add a **Wait timer** (e.g., 5 minutes)
5. Optional: restrict **Deployment branches** to `main` only

### 2. Secrets

The workflows use Workload Identity Federation (WIF) to authenticate to GCP — no long-lived credentials stored in GitHub. Secrets are pulled at runtime from GCP Secret Manager.

Required GitHub secrets (should already exist from the plan workflow):

| Secret | Description |
|--------|-------------|
| `WIF_PROVIDER_DEV` | WIF provider for dev project |
| `SA_EMAIL_DEV` | Service account email for dev |
| `WIF_PROVIDER_PROD` | WIF provider for prod project |
| `SA_EMAIL_PROD` | Service account email for prod |
| `WIF_PROVIDER_CENTRAL` | WIF provider for central project |
| `SA_EMAIL_CENTRAL` | Service account email for central |
| `AWS_ACCESS_KEY_ID_PROD` | AWS key for Route53 (prod only) |
| `AWS_SECRET_ACCESS_KEY_PROD` | AWS secret for Route53 (prod only) |

### 3. Terraform Version

Both workflows pin Terraform to **v1.6.1** via the `TF_VERSION` env var.

## Flow Diagram

```
PR opened ──► terraform-plan.yml
               ├── Plan dev    ──► PR comment
               ├── Plan prod   ──► PR comment
               └── Plan central ──► PR comment

PR merged to main ──► terraform-apply.yml
                       ├── Dev:  Plan → Apply (auto)
                       ├── Prod: Plan → ⏸ Approval → Re-plan → Apply
                       └── Central: (manual dispatch only)
```
