variable "tenant_id" {
  description = "Unique identifier for the tenant"
  type        = string
}

variable "tenant_name" {
  description = "Human readable tenant name"
  type        = string
}

variable "tenant_email" {
  description = "Primary email for the tenant"
  type        = string
}

variable "platform_bucket" {
  description = "Name of the shared S3 bucket"
  type        = string
}

variable "dynamodb_table" {
  description = "Name of the shared DynamoDB table"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "ID of the Cognito user pool"
  type        = string
}