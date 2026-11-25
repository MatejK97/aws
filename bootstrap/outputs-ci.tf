output "ci_plan_user" {
  description = "Create its key with: aws iam create-access-key --user-name <this>"
  value       = aws_iam_user.ci_plan.name
}

output "ci_apply_user" {
  description = "Create its key with: aws iam create-access-key --user-name <this>"
  value       = aws_iam_user.ci_apply.name
}
