provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Applied to every resource this provider creates
  default_tags {
    tags = {
      Project     = "flight-delay-intelligence"
      ManagedBy   = "terraform"
      Environment = "bootstrap"
    }
  }
}
