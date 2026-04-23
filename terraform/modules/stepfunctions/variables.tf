variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "tenant_id" {
  description = "Tenant identifier"
  type        = string
}

variable "intake_handler_arn" {
  description = "ARN of the intake handler Lambda function"
  type        = string
}

variable "content_generator_arn" {
  description = "ARN of the content generator Lambda function"
  type        = string
}

variable "step_functions_role_arn" {
  description = "ARN of the Step Functions IAM role"
  type        = string
}