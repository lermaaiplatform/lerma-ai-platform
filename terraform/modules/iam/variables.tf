variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "platform_bucket_arn" {
  description = "ARN of the platform S3 bucket"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  type        = string
}