variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "tenant_id" {
  description = "Tenant identifier"
  type        = string
}

variable "proxycurl_api_key" {
  description = "Proxycurl API key for LinkedIn data"
  type        = string
  sensitive   = true
}