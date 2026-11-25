# Two IAM users for GitLab CI, the same split as the terraform repo's two
# GitLab tokens. Their access keys are created with the CLI, not here, so the
# secrets never land in Terraform state.
#
# - plan:  read-only, used by every pipeline including merge requests
# - apply: can change only what the CI-managed stacks own, used by the manual
#          apply job on main (its keys are protected CI variables)
#
# Neither user can change the state bucket's settings, its own permissions,
# or the permissions boundary.

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  state_arns = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]

  # Everything the CI-managed stacks create is named matthomelab-*
  stack_bucket_arns = ["arn:aws:s3:::matthomelab-*", "arn:aws:s3:::matthomelab-*/*"]

  # IAM principals the stacks create live under /homelab/; the CI users
  # themselves live under /homelab/ci/ and are off limits to the stacks
  workload_principals = [
    "arn:aws:iam::${local.account_id}:user/homelab/*",
    "arn:aws:iam::${local.account_id}:role/homelab/*",
  ]
  ci_principals = ["arn:aws:iam::${local.account_id}:user/homelab/ci/*"]
}

# --- plan: read-only --------------------------------------------------------

resource "aws_iam_user" "ci_plan" {
  name = "gitlab-ci-aws-plan"
  path = "/homelab/ci/"
}

resource "aws_iam_user_policy_attachment" "ci_plan_readonly" {
  user       = aws_iam_user.ci_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_user_policy" "ci_plan_limits" {
  name = "plan-limits"
  user = aws_iam_user.ci_plan.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ReadOnlyAccess can read any object; the backups don't need a CI reader
        Sid      = "NoBackupData"
        Effect   = "Deny"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::matthomelab-restic-offsite/*"
      },
    ]
  })
}

# --- apply: changes only what the stacks own --------------------------------

resource "aws_iam_user" "ci_apply" {
  name = "gitlab-ci-aws-apply"
  path = "/homelab/ci/"
}

resource "aws_iam_user_policy" "ci_apply" {
  name = "apply-stacks"
  user = aws_iam_user.ci_apply.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WhoAmI"
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      },
      {
        # Read and write the stacks' state files and lock files
        Sid      = "StateFiles"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = local.state_arns
      },
      {
        Sid      = "StackBuckets"
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = local.stack_bucket_arns
      },
      {
        # The state bucket is also matthomelab-*: only its objects, never its settings
        Sid       = "StateBucketSettingsAreBootstrapOnly"
        Effect    = "Deny"
        NotAction = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource  = local.state_arns
      },
      {
        Sid    = "ReadIam"
        Effect = "Allow"
        Action = ["iam:Get*", "iam:List*"]
        Resource = concat(local.workload_principals, [
          "arn:aws:iam::${local.account_id}:policy/homelab/*",
        ])
      },
      {
        # New users and roles only with the boundary attached
        Sid    = "CreatePrincipalsWithBoundary"
        Effect = "Allow"
        Action = [
          "iam:CreateUser",
          "iam:CreateRole",
          "iam:PutUserPermissionsBoundary",
          "iam:PutRolePermissionsBoundary",
        ]
        Resource = local.workload_principals
        Condition = {
          StringEquals = { "iam:PermissionsBoundary" = aws_iam_policy.boundary.arn }
        }
      },
      {
        Sid    = "ManageWorkloadPrincipals"
        Effect = "Allow"
        Action = [
          "iam:DeleteUser",
          "iam:DeleteRole",
          "iam:TagUser",
          "iam:UntagUser",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:UpdateAssumeRolePolicy",
        ]
        Resource = local.workload_principals
      },
      {
        # Reading is fine (the backup stack looks the boundary up by name);
        # changing the CI users or the boundary is bootstrap-only
        Sid       = "NeverChangeCiUsersOrBoundary"
        Effect    = "Deny"
        NotAction = ["iam:Get*", "iam:List*"]
        Resource  = concat(local.ci_principals, [aws_iam_policy.boundary.arn])
      },
      {
        Sid    = "NeverRemoveBoundaries"
        Effect = "Deny"
        Action = [
          "iam:DeleteUserPermissionsBoundary",
          "iam:DeleteRolePermissionsBoundary",
        ]
        Resource = "*"
      },
    ]
  })
}
