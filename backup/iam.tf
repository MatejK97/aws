# The boundary from the bootstrap stack, looked up by name
data "aws_iam_policy" "boundary" {
  name = "homelab-boundary"
}

# One IAM user for the home VM. Its access key is created with the CLI,
# not here, so the secret never lands in Terraform state.
resource "aws_iam_user" "restic" {
  name                 = "restic-${var.host}"
  path                 = "/homelab/"
  permissions_boundary = data.aws_iam_policy.boundary.arn
}

resource "aws_iam_user_policy" "restic" {
  name = "restic-offsite-copy"
  user = aws_iam_user.restic.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListTheBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.restic.arn
      },
      {
        # Delete is needed for restic's prune and lock files; with versioning
        # it only creates a delete marker
        Sid      = "ReadWriteObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.restic.arn}/*"
      },
      {
        # A stolen key can't destroy history or loosen the bucket's protection
        Sid    = "NeverDestroyHistory"
        Effect = "Deny"
        Action = [
          "s3:DeleteObjectVersion",
          "s3:DeleteBucket",
          "s3:PutBucketVersioning",
          "s3:PutLifecycleConfiguration",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:PutBucketObjectLockConfiguration",
        ]
        Resource = [aws_s3_bucket.restic.arn, "${aws_s3_bucket.restic.arn}/*"]
      },
    ]
  })
}
