output "proxycurl_secret_arn" {
  description = "ARN of the Proxycurl API key secret"
  value       = aws_secretsmanager_secret.proxycurl.arn
}

output "proxycurl_secret_name" {
  description = "Name of the Proxycurl API key secret"
  value       = aws_secretsmanager_secret.proxycurl.name
}

output "read_secrets_policy_arn" {
  description = "ARN of the IAM policy for reading secrets"
  value       = aws_iam_policy.read_secrets.arn
}