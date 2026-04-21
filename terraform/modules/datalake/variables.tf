variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "platform_bucket_name" {
  description = "Name of the platform S3 bucket"
  type        = string
}

variable "platform_bucket_arn" {
  description = "ARN of the platform S3 bucket"
  type        = string
}

variable "tenant_ids" {
  description = "List of tenant IDs to create database and crawler for"
  type        = list(string)
  default     = ["tenant-001"]
}