variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "bucket_name" {
  description = "Bucket for the off-site restic copy"
  type        = string
  default     = "matthomelab-restic-offsite"
}

variable "host" {
  description = "The host that writes the copy (gets its own IAM user)"
  type        = string
  default     = "ubuntu01"
}

variable "noncurrent_days" {
  description = "How long deleted or overwritten objects can still be recovered"
  type        = number
  default     = 30
}
