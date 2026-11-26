variable "region" {
  description = "AWS region for the content bucket"
  type        = string
  default     = "eu-central-1"
}

variable "domain" {
  description = "The site's domain; www redirects to it"
  type        = string
  default     = "matthomelab.xyz"
}

variable "bucket_name" {
  description = "Private bucket with the site's files"
  type        = string
  default     = "matthomelab-website"
}

variable "rate_limit" {
  description = "Requests per IP per 5 minutes before the WAF blocks it"
  type        = number
  default     = 300
}

variable "counter_reserved_concurrency" {
  description = "Reserved concurrency for the counter Lambda; -1 for none (needs room in the account's quota)"
  type        = number
  default     = -1
}
