# Credentials come from the environment (AWS_PROFILE=homelab), never from code
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project    = "homelab"
      Stack      = "bootstrap"
      ManagedBy  = "terraform"
      Repository = "homelab/aws"
    }
  }
}
