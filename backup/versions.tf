terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State bucket from the bootstrap stack; S3 native locking, no DynamoDB table
  backend "s3" {
    bucket       = "matthomelab-terraform-state"
    key          = "backup/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
