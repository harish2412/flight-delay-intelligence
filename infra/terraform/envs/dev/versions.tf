terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state in the bucket created by infra/terraform/bootstrap.
  # The bucket name is supplied at init time from backend.hcl (kept out of Git),
  # because backend blocks can't use variables.
  backend "s3" {
    key          = "envs/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # S3-native state locking (Terraform 1.10+), no DynamoDB table needed
  }
}
