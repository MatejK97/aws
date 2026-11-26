# Extra permissions for the apply user: the website stack's CloudFront
# distribution, its certificate and its WAF web ACL. A managed policy rather
# than more statements in the inline one, which is close to IAM's 2,048
# character limit for inline user policies.
#
# The apply user has no permission to create, change or attach IAM policies,
# and can't detach anything from itself (the inline policy denies changes to
# the CI users), so it can't widen this policy.

resource "aws_iam_policy" "ci_apply_website" {
  name        = "homelab-ci-apply-website"
  path        = "/homelab/ci/"
  description = "CloudFront, ACM and WAF for the CI-managed website stack"

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
    ]
  })
}

resource "aws_iam_user_policy_attachment" "ci_apply_website" {
  user       = aws_iam_user.ci_apply.name
  policy_arn = aws_iam_policy.ci_apply_website.arn
}
