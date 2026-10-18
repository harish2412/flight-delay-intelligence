variable "bucket_name" {
  description = "Globally unique name for the bucket"
  type        = string
}

variable "versioning_enabled" {
  description = "Keep previous versions of objects. Useful for artifacts, unnecessary for re-downloadable raw data"
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete the bucket even if it contains objects. Convenient in dev, dangerous in prod"
  type        = bool
  default     = false
}

variable "noncurrent_version_days" {
  description = "Days to keep previous object versions before deleting them (only applies when versioning is on)"
  type        = number
  default     = 30
}
