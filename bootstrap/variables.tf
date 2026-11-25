variable "region" {
  description = "AWS region for everything in this repo"
  type        = string
  default     = "eu-central-1"
}

variable "state_bucket_name" {
  description = "S3 bucket that holds the Terraform state of every stack"
  type        = string
  default     = "matthomelab-terraform-state"
}

variable "budget_email" {
  description = "Where budget and cost anomaly alerts are sent"
  type        = string
}

variable "budget_limit_usd" {
  description = "Monthly budget; alerts at 100% actual and 100% forecast"
  type        = string
  default     = "5"
}

variable "budget_warning_usd" {
  description = "Early warning: alert when actual spend passes this amount"
  type        = number
  default     = 3
}

variable "create_cost_anomaly_monitor" {
  description = "AWS may already have created a default services monitor (only one is allowed); check before enabling"
  type        = bool
  default     = false
}
