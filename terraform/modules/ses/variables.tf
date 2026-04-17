variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "from_email" {
  description = "Email address to verify for sending"
  type        = string
  sensitive   = true
}