data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  prefix     = "${var.project}-${var.environment}"

  # One entry per data lake bucket. Add a line here to add a bucket.
  data_lake_buckets = {
    raw = {
      versioning = false # landing zone for downloaded and streamed data; re-downloadable
    }
    curated = {
      versioning = false # cleaned Parquet/Delta output from Databricks; rebuildable from raw
    }
    artifacts = {
      versioning = true # ML models, MLflow artifacts, RAG documents; worth keeping history
    }
  }
}

# for_each creates one module instance per map entry: module.data_lake["raw"], etc.
module "data_lake" {
  source   = "../../aws/s3_bucket"
  for_each = local.data_lake_buckets

  bucket_name        = "${local.prefix}-${each.key}-${local.account_id}"
  versioning_enabled = each.value.versioning
  force_destroy      = true # dev only: lets terraform destroy remove buckets with data in them
}
