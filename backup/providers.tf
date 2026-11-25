provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project    = "homelab"
      Stack      = "backup"
      ManagedBy  = "terraform"
      Repository = "homelab/aws"
    }
  }
}
