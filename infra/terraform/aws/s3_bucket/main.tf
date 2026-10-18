# A reusable, secure-by-default S3 bucket.
# Every bucket created from this module gets the same protections.

resource "aws_s3_bucket" "this" {
  #checkov:skip=CKV_AWS_18:Access logging needs a separate log bucket; CloudTrail covers management events for this personal project
  #checkov:skip=CKV2_AWS_62:Event notifications are added per bucket only where a consumer needs them
  #checkov:skip=CKV_AWS_145:SSE-S3 (AES256) is sufficient; a customer-managed KMS key adds monthly cost
  #checkov:skip=CKV_AWS_144:Cross-region replication doubles storage cost; not needed for a personal project
  #checkov:skip=CKV_AWS_21:Versioning is configurable per bucket; raw data can be re-downloaded from its source
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
}

# Disables legacy ACLs so access is controlled only through IAM and bucket policies
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    # "Disabled" is only valid for a bucket that has never had versioning turned on
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "housekeeping"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}
