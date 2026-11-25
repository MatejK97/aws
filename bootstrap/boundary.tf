# Permissions boundary for every IAM user and role created outside this stack
# (the backup user now; CI-created roles later). A boundary caps what a
# principal can ever do, whatever policies are attached to it, so whoever
# creates principals can't create one more powerful than intended.
resource "aws_iam_policy" "boundary" {
  name        = "homelab-boundary"
  path        = "/homelab/"
  description = "Upper limit for IAM principals created by the homelab stacks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WorkloadServices"
        Effect   = "Allow"
        Action   = ["s3:*", "dynamodb:*", "logs:*", "sts:GetCallerIdentity"]
        Resource = "*"
      },
      {
        Sid      = "NeverTouchTerraformState"
        Effect   = "Deny"
        Action   = "s3:*"
        Resource = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
      },
      {
        Sid    = "NoIdentityOrAccountChanges"
        Effect = "Deny"
        Action = [
          "iam:*",
          "organizations:*",
          "account:*",
          "sso:*",
          "identitystore:*",
        ]
        Resource = "*"
      },
    ]
  })
}
