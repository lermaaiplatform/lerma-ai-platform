output "platform_bucket_name" {
  description = "Platform S3 bucket name"
  value       = module.platform.platform_bucket_name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.platform.dynamodb_table_name
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID"
  value       = module.platform.cognito_user_pool_id
}
