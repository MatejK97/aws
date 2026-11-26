locals {
  tags = {
    Project    = "homelab"
    Stack      = "website"
    ManagedBy  = "terraform"
    Repository = "homelab/aws"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

# CloudFront only accepts certificates and WAF web ACLs from us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.tags
  }
}

# Token from CLOUDFLARE_API_TOKEN: read-only for plans, DNS edit for apply
provider "cloudflare" {}
