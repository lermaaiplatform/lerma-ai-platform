variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "platform_bucket_name" {
  description = "Name of the platform S3 bucket"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "intake_lambda_role_arn" {
  description = "ARN of the intake Lambda IAM role"
  type        = string
}

variable "content_generator_lambda_role_arn" {
  description = "ARN of the content generator Lambda IAM role"
  type        = string
}

variable "tenant_id" {
  description = "Tenant identifier"
  type        = string
}

variable "from_email" {
  description = "Verified SES email address for sending"
  type        = string
  sensitive   = true
}

variable "notify_email" {
  description = "Email address to receive notifications"
  type        = string
  sensitive   = true
}