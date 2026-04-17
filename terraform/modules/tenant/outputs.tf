output "tenant_id" {
  description = "Tenant identifier"
  value       = var.tenant_id
}

output "knowledge_base_prefix" {
  description = "S3 prefix for tenant knowledge base"
  value       = "coaches/${var.tenant_id}/knowledge-base/"
}

output "content_drafts_prefix" {
  description = "S3 prefix for tenant content drafts"
  value       = "coaches/${var.tenant_id}/content-drafts/"
}

output "audit_logs_prefix" {
  description = "S3 prefix for tenant audit logs"
  value       = "coaches/${var.tenant_id}/audit-logs/"
}

output "prompt_templates_prefix" {
  description = "S3 prefix for tenant prompt templates"
  value       = "coaches/${var.tenant_id}/prompt-templates/"
}

output "cognito_username" {
  description = "Cognito username for tenant admin"
  value       = aws_cognito_user.tenant_admin.username
}