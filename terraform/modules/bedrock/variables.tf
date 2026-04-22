variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "tenant_id" {
  description = "Tenant identifier"
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