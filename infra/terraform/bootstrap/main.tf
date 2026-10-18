# Looks up the account you're authenticated as, so the bucket name is unique
data "aws_caller_identity" "current" {}

locals {
  state_bucket_name = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
}

# The bucket that will store Terraform state for the rest of the project
resource "aws_s3_bucket" "tf_state" {
  #checkov:skip=CKV_AWS_18:Access logging needs a second bucket; CloudTrail covers management events for this personal project
  #checkov:skip=CKV2_AWS_62:No downstream consumers need events from the state bucket
  #checkov:skip=CKV_AWS_145:SSE-S3 (AES256) is sufficient here; a customer-managed KMS key adds monthly cost
  #checkov:skip=CKV_AWS_144:Cross-region replication doubles storage cost; versioning already covers recovery
  bucket = local.state_bucket_name

  # Guards against accidentally deleting the bucket that holds all your state
  lifecycle {
    prevent_destroy = true
  }
}

# Keeps every previous version of the state file, so a bad apply can be rolled back
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Cleans up old state versions and abandoned uploads to keep storage costs down
resource "aws_s3_bucket_lifecycle_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    # Deletes previous versions after 90 days, but always keeps the 10 most recent
    noncurrent_version_expiration {
      noncurrent_days           = 90
      newer_noncurrent_versions = 10
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.tf_state]
}

# Encrypts state at rest (state files can contain sensitive values)
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Blocks every form of public access
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Rejects any request that isn't sent over HTTPS
resource "aws_s3_bucket_policy" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tf_state.arn,
          "${aws_s3_bucket.tf_state.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.tf_state]
}
