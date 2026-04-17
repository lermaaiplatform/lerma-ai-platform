output "ses_email_identity_arn" {
  description = "ARN of the verified SES email identity"
  value       = aws_ses_email_identity.platform.arn
}

output "ses_configuration_set_name" {
  description = "Name of the SES configuration set"
  value       = aws_ses_configuration_set.platform.name
}