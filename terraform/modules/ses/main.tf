# SES Email Identity Verification
resource "aws_ses_email_identity" "platform" {
  email = var.from_email
}

# SES Configuration Set
resource "aws_ses_configuration_set" "platform" {
  name = "lerma-aiplatform-config-${var.environment}"
}

# CloudWatch Log Group for SES
resource "aws_cloudwatch_log_group" "ses" {
  name              = "/aws/ses/lerma-aiplatform-${var.environment}"
  retention_in_days = 30
}