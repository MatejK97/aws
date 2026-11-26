# Extra permissions for the apply user: the website stack's CloudFront
# distribution, its certificate, its WAF web ACL and the visitor counter
# (Lambda, DynamoDB, the function's log group). A managed policy rather
# than more statements in the inline one, which is close to IAM's 2,048
# character limit for inline user policies.
#
# The apply user has no permission to create, change or attach IAM policies,
# and can't detach anything from itself (the inline policy denies changes to
# the CI users), so it can't widen this policy.

# Changing the description replaces the policy (IAM can't update it in place)
resource "aws_iam_policy" "ci_apply_website" {
  name        = "homelab-ci-apply-website"
  path        = "/homelab/ci/"
  description = "CloudFront, ACM, WAF, Lambda and DynamoDB for the CI-managed website stack"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Distributions, origin access controls, functions, invalidations
        Sid      = "CloudFront"
        Effect   = "Allow"
        Action   = "cloudfront:*"
        Resource = "*"
      },
      {
        # CloudFront only accepts certificates and web ACLs from us-east-1,
        # so nothing anywhere else
        Sid      = "CertificateAndWafInUsEast1"
        Effect   = "Allow"
        Action   = ["acm:*", "wafv2:*"]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" = "us-east-1" }
        }
      },
      {
        # Functions, their URLs, permissions and concurrency; named matthomelab-*
        Sid      = "CounterFunction"
        Effect   = "Allow"
        Action   = "lambda:*"
        Resource = "arn:aws:lambda:${var.region}:${local.account_id}:function:matthomelab-*"
      },
      {
        # Hand a role to Lambda, and only to Lambda. The roles themselves are
        # created under /homelab/ with the permissions boundary (inline policy).
        Sid      = "PassWorkloadRolesToLambda"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${local.account_id}:role/homelab/*"
        Condition = {
          StringEquals = { "iam:PassedToService" = "lambda.amazonaws.com" }
        }
      },
      {
        Sid      = "CounterTable"
        Effect   = "Allow"
        Action   = "dynamodb:*"
        Resource = "arn:aws:dynamodb:${var.region}:${local.account_id}:table/matthomelab-*"
      },
      {
        Sid    = "FunctionLogGroups"
        Effect = "Allow"
        Action = "logs:*"
        Resource = [
          "arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/lambda/matthomelab-*",
          "arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/lambda/matthomelab-*:*",
        ]
      },
      {
        # Terraform lists log groups to read one back; this call can't be scoped
        Sid      = "ListLogGroups"
        Effect   = "Allow"
        Action   = "logs:DescribeLogGroups"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "ci_apply_website" {
  user       = aws_iam_user.ci_apply.name
  policy_arn = aws_iam_policy.ci_apply_website.arn
}
