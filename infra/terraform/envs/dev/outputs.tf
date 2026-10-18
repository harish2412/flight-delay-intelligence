output "data_lake_bucket_names" {
  description = "Data lake bucket names, keyed by zone"
  value       = { for zone, bucket in module.data_lake : zone => bucket.bucket_name }
}

output "data_lake_bucket_arns" {
  description = "Data lake bucket ARNs, keyed by zone"
  value       = { for zone, bucket in module.data_lake : zone => bucket.bucket_arn }
}
