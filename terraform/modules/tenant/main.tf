# S3 Tenant Prefix Structure
resource "aws_s3_object" "knowledge_base_prefix" {
  bucket  = var.platform_bucket
  key     = "coaches/${var.tenant_id}/knowledge-base/.keep"
  content = ""
}

resource "aws_s3_object" "content_drafts_prefix" {
  bucket  = var.platform_bucket
  key     = "coaches/${var.tenant_id}/content-drafts/.keep"
  content = ""
}

resource "aws_s3_object" "audit_logs_prefix" {
  bucket  = var.platform_bucket
  key     = "coaches/${var.tenant_id}/audit-logs/.keep"
  content = ""
}

resource "aws_s3_object" "prompt_templates_prefix" {
  bucket  = var.platform_bucket
  key     = "coaches/${var.tenant_id}/prompt-templates/.keep"
  content = ""
}

# DynamoDB Tenant Seed Record
resource "aws_dynamodb_table_item" "tenant_record" {
  table_name = var.dynamodb_table
  hash_key   = "PK"
  range_key  = "SK"

  item = jsonencode({
    PK         = { S = "TENANT#${var.tenant_id}" }
    SK         = { S = "PROFILE#${var.tenant_id}" }
    tenantId   = { S = var.tenant_id }
    tenantName = { S = var.tenant_name }
    email      = { S = var.tenant_email }
    status     = { S = "ACTIVE" }
    createdAt  = { S = timestamp() }
  })
}

# Cognito Tenant User
resource "aws_cognito_user" "tenant_admin" {
  user_pool_id = var.cognito_user_pool_id
  username     = var.tenant_id

  attributes = {
    email          = var.tenant_email
    email_verified = "true"
  }

  temporary_password   = "TempPass123!"
  force_alias_creation = false

  lifecycle {
    ignore_changes = [temporary_password]
  }
}