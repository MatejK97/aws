# aws

My AWS account, managed with Terraform: an off-site copy of the homelab's
backups today, and the CV website at `matthomelab.xyz` next. Built to stay
inside a $5 monthly budget, with cost and access guardrails built in.

> A published snapshot of a repository that runs on my self-hosted GitLab.
> More about the lab: [homelab](https://github.com/MatejK97/homelab)

```
bootstrap/   state bucket, budget and cost alerts, permissions boundary, CI users
backup/      off-site copy of the restic backups: bucket + IAM user for the home VM
```

Each folder is its own Terraform root with its own state file, so a change in
one stack can't touch another.

## Design

- **State:** an S3 bucket with versioning, encryption, TLS-only access and
  S3-native state locking (`use_lockfile`, no DynamoDB table). The bucket is
  created by the `bootstrap` stack, which then moves its own state into it.
- **People sign in with IAM Identity Center** (`aws sso login`), never with
  long-lived keys. The root user has MFA and no access keys.
- **Two CI users, the same split as my GitLab tokens:**
  - `gitlab-ci-aws-plan`: `ReadOnlyAccess` for plans in merge requests, minus
    reading the backup objects.
  - `gitlab-ci-aws-apply`: a protected variable, so only `main` pipelines get
    it. It can write state and manage the stacks' resources, and it can only
    create IAM principals that carry the permissions boundary.
- **Permissions boundary:** every principal a stack creates is capped by
  `homelab-boundary`: no IAM, Organizations or account changes, and no access
  to the state bucket, whatever policy is attached later.
- **The bootstrap stack is never run in CI.** It manages the CI users' own
  permissions, so CI can't widen its own access.
- **Access keys are created with the CLI, not Terraform**, so no secret ever
  lands in the state file.
- **Cost guardrails:** AWS Budgets emails at $3, at the $5 limit and when the
  forecast passes it; Cost Anomaly Detection emails daily on any unusual
  spend.

## Off-site backups

The home VM's restic repository is copied nightly to S3 with `restic copy`,
then pruned and checked there. The data is encrypted by restic before it
leaves the house.

- The backup user can add and delete objects but has no
  `s3:DeleteObjectVersion`, and the bucket is versioned: a stolen key can hide
  data, not destroy it. Old versions expire after 30 days.
- A full restore from S3 was tested end to end (GitLab backup archive,
  secrets file, Kubernetes Secrets, SQLite databases).
- healthchecks.io alerts if the nightly copy fails or doesn't run.

## Pipeline

GitLab CI on my self-hosted GitLab:

- **Every pipeline:** `terraform fmt -check`, `validate` for every stack,
  gitleaks for secrets and a Trivy misconfiguration scan. Accepted findings
  are listed with reasons in `.trivyignore.yaml`.
- **Merge requests:** a plan for each stack that changed, with the summary
  (to add / change / destroy) shown in the MR.
- **`main`:** the saved plan is applied through a **manual** step, one stack
  at a time (`resource_group`).

The public GitHub copy runs the same checks with GitHub Actions, without any
AWS access.

## Running it locally

Prerequisites: Terraform 1.14+, AWS CLI v2, and
`aws sso login --profile homelab` with `AWS_PROFILE=homelab`.

### Bootstrap (once, and for changes to the CI users)

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # set budget_email
aws ce get-anomaly-monitors                    # no SERVICE monitor? set create_cost_anomaly_monitor = true
terraform init
terraform fmt -check && terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

On the very first run there's no bucket for the state yet: start without
`backend.tf`, apply, then add it back and run `terraform init -migrate-state`.

### Other stacks

Changed through merge requests and applied by the pipeline. Access keys for
the users the stacks create are made outside Terraform:

```bash
aws iam create-access-key --user-name restic-ubuntu01
```

### Lock files

Commit each stack's `.terraform.lock.hcl` with checksums for both platforms:

```bash
terraform providers lock -platform=windows_amd64 -platform=linux_amd64
```
