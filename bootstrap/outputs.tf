output "state_bucket" {
  description = "Use in every stack's backend block"
  value       = aws_s3_bucket.state.id
}

output "boundary_policy_arn" {
  description = "Attach as permissions_boundary to every IAM user and role"
  value       = aws_iam_policy.boundary.arn
}
