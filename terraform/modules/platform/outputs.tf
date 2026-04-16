output "platform_bucket_name" {
  description = "Name of the platform S3 bucket"
  value       = aws_s3_bucket.platform.bucket
}

output "platform_bucket_arn" {
  description = "ARN of the platform S3 bucket"
  value       = aws_s3_bucket.platform.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.platform.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.platform.arn
}

output "cognito_user_pool_id" {
  description = "ID of the Cognito user pool"
  value       = aws_cognito_user_pool.platform.id
}

output "cognito_client_id" {
  description = "ID of the Cognito app client"
  value       = aws_cognito_user_pool_client.platform.id
}