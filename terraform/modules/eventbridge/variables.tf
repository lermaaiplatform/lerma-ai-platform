variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "content_generator_arn" {
  description = "ARN of the content generator Lambda function"
  type        = string
}

variable "content_generator_name" {
  description = "Name of the content generator Lambda function"
  type        = string
}

variable "tenant_id" {
  description = "Tenant identifier"
  type        = string
}