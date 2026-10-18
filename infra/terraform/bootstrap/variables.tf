variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile used to authenticate"
  type        = string
  default     = "flight-delay"
}

variable "project" {
  description = "Short project name used as a prefix in resource names"
  type        = string
  default     = "flight-delay"
}
