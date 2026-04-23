# Proxycurl API Key Secret
resource "aws_secretsmanager_secret" "proxycurl" {
  name                    = "lerma-platform/${var.environment}/${var.tenant_id}/proxycurl-api-key"
  description             = "Proxycurl API key for LinkedIn data fetching for ${var.tenant_id}"
  recovery_window_in_days = 7

  tags = {
    TenantId = var.tenant_id
  }
}

resource "aws_secretsmanager_secret_version" "proxycurl" {
  secret_id     = aws_secretsmanager_secret.proxycurl.id
  secret_string = var.proxycurl_api_key
}

# IAM policy document for Lambda to read secrets
data "aws_iam_policy_document" "read_secrets" {
  statement {
    sid    = "ReadProxycurlSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      aws_secretsmanager_secret.proxycurl.arn
    ]
  }
}

# Managed policy for Lambda roles to attach
resource "aws_iam_policy" "read_secrets" {
  name        = "lerma-platform-read-secrets-${var.tenant_id}-${var.environment}"
  description = "Allows Lambda functions to read platform secrets"
  policy      = data.aws_iam_policy_document.read_secrets.json
}

# Attach secrets policy to content generator Lambda role
resource "aws_iam_role_policy_attachment" "content_generator_secrets" {
  role       = "lerma-platform-content-lambda-${var.environment}"
  policy_arn = aws_iam_policy.read_secrets.arn
}