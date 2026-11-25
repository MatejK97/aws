output "bucket" {
  value = aws_s3_bucket.restic.id
}

output "restic_repository" {
  description = "RESTIC_REPOSITORY for the S3 copy"
  value       = "s3:s3.${var.region}.amazonaws.com/${aws_s3_bucket.restic.id}/vps"
}

output "iam_user" {
  description = "Create its access key with: aws iam create-access-key --user-name <this>"
  value       = aws_iam_user.restic.name
}
