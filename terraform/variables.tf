variable "tenant_001_email" {
  description = "Primary email address for tenant 001"
  type        = string
  sensitive   = true
}

variable "proxycurl_api_key" {
  description = "Proxycurl API key for LinkedIn data"
  type        = string
  sensitive   = true
  default     = "placeholder-key-replace-after-signup"
}