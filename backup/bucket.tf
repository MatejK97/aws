# Off-site copy of the VPS backups. The home VM copies its restic repository
# here with `restic copy`; the VPS itself never gets AWS credentials.
resource "aws_s3_bucket" "restic" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "restic" {
  bucket = aws_s3_bucket.restic.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "restic" {
  bucket = aws_s3_bucket.restic.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# With versioning, a delete only adds a delete marker: the data stays
# recoverable for var.noncurrent_days, and the backup user can't remove versions
resource "aws_s3_bucket_versioning" "restic" {
  bucket = aws_s3_bucket.restic.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "restic" {
  bucket = aws_s3_bucket.restic.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Standard on purpose: restic reads data back during prune and check, so
# Standard-IA would add retrieval fees and a 30-day minimum for pruned packs.
resource "aws_s3_bucket_lifecycle_configuration" "restic" {
  bucket = aws_s3_bucket.restic.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    filter {}

    # Deleted or replaced data is kept this long, then removed for good
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_days
    }

    # Remove delete markers once nothing is left behind them
    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.restic]
}

resource "aws_s3_bucket_policy" "restic" {
  bucket = aws_s3_bucket.restic.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.restic.arn, "${aws_s3_bucket.restic.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.restic]
}
