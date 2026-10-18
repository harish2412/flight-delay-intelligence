# Modules declare which providers they need, but never configure them.
# The calling configuration (envs/dev) passes its configured provider in.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
