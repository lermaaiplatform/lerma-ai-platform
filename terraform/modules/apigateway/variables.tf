variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "intake_handler_arn" {
  description = "ARN of the intake handler Lambda function"
  type        = string
}

variable "intake_handler_name" {
  description = "Name of the intake handler Lambda function"
  type        = string
}