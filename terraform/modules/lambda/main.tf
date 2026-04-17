# Zip the intake handler source code
data "archive_file" "intake_handler" {
  type        = "zip"
  source_file = "${path.root}/../lambda/intake-handler/index.py"
  output_path = "${path.root}/../lambda/intake-handler/intake-handler.zip"
}

# Zip the content generator source code
data "archive_file" "content_generator" {
  type        = "zip"
  source_file = "${path.root}/../lambda/content-generator/index.py"
  output_path = "${path.root}/../lambda/content-generator/content-generator.zip"
}

# Intake Handler Lambda Function
resource "aws_lambda_function" "intake_handler" {
  function_name    = "lerma-platform-intake-handler-${var.environment}"
  filename         = data.archive_file.intake_handler.output_path
  source_code_hash = data.archive_file.intake_handler.output_base64sha256
  role             = var.intake_lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      PLATFORM_BUCKET = var.platform_bucket_name
      FROM_EMAIL     = var.from_email
      NOTIFY_EMAIL   = var.notify_email
      TENANT_ID      = var.tenant_id
    }
  }
}

# Content Generator Lambda Function
resource "aws_lambda_function" "content_generator" {
  function_name    = "lerma-platform-content-generator-${var.environment}"
  filename         = data.archive_file.content_generator.output_path
  source_code_hash = data.archive_file.content_generator.output_base64sha256
  role             = var.content_generator_lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 512

  environment {
    variables = {
      DYNAMODB_TABLE  = var.dynamodb_table_name
      PLATFORM_BUCKET = var.platform_bucket_name
      FROM_EMAIL      = var.from_email
      NOTIFY_EMAIL    = var.notify_email
      TENANT_ID       = var.tenant_id
    }
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "intake_handler" {
  name              = "/aws/lambda/lerma-platform-intake-handler-${var.environment}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "content_generator" {
  name              = "/aws/lambda/lerma-platform-content-generator-${var.environment}"
  retention_in_days = 30
}