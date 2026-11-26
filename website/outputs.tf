output "bucket" {
  description = "Where CI syncs the site's files"
  value       = aws_s3_bucket.site.id
}

output "distribution_id" {
  description = "For invalidations and the flat-rate plan subscription"
  value       = aws_cloudfront_distribution.site.id
}

output "distribution_domain" {
  value = aws_cloudfront_distribution.site.domain_name
}

output "url" {
  value = "https://${var.domain}"
}
