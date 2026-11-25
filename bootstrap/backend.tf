# Rename to backend.tf after the first apply, then run:
#   terraform init -migrate-state
# Terraform copies this stack's local state into the bucket it just created.
terraform {
  backend "s3" {
    bucket       = "matthomelab-terraform-state"
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
