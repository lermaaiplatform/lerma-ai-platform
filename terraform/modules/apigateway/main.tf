# API Gateway REST API
resource "aws_api_gateway_rest_api" "platform" {
  name        = "lerma-aiplatform-api-${var.environment}"
  description = "Lerma AI Platform API for prospect intake and content generation"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Resource: /intake
resource "aws_api_gateway_resource" "intake" {
  rest_api_id = aws_api_gateway_rest_api.platform.id
  parent_id   = aws_api_gateway_rest_api.platform.root_resource_id
  path_part   = "intake"
}

# Method: POST /intake
resource "aws_api_gateway_method" "intake_post" {
  rest_api_id      = aws_api_gateway_resource.intake.rest_api_id
  resource_id      = aws_api_gateway_resource.intake.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

# Integration: POST /intake → Lambda
resource "aws_api_gateway_integration" "intake_post" {
  rest_api_id             = aws_api_gateway_resource.intake.rest_api_id
  resource_id             = aws_api_gateway_resource.intake.id
  http_method             = aws_api_gateway_method.intake_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/${var.intake_handler_arn}/invocations"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_intake" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.intake_handler_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.platform.execution_arn}/*/*"
}

# CORS: OPTIONS /intake
resource "aws_api_gateway_method" "intake_options" {
  rest_api_id   = aws_api_gateway_resource.intake.rest_api_id
  resource_id   = aws_api_gateway_resource.intake.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "intake_options" {
  rest_api_id = aws_api_gateway_resource.intake.rest_api_id
  resource_id = aws_api_gateway_resource.intake.id
  http_method = aws_api_gateway_method.intake_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "intake_options" {
  rest_api_id = aws_api_gateway_resource.intake.rest_api_id
  resource_id = aws_api_gateway_resource.intake.id
  http_method = aws_api_gateway_method.intake_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "intake_options" {
  rest_api_id = aws_api_gateway_resource.intake.rest_api_id
  resource_id = aws_api_gateway_resource.intake.id
  http_method = aws_api_gateway_method.intake_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Api-Key'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.intake_options]
}

# Deployment
resource "aws_api_gateway_deployment" "platform" {
  rest_api_id = aws_api_gateway_rest_api.platform.id

  depends_on = [
    aws_api_gateway_integration.intake_post,
    aws_api_gateway_integration.intake_options
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Stage
resource "aws_api_gateway_stage" "platform" {
  rest_api_id   = aws_api_gateway_rest_api.platform.id
  deployment_id = aws_api_gateway_deployment.platform.id
  stage_name    = var.environment
}

# API Key
resource "aws_api_gateway_api_key" "platform" {
  name    = "lerma-aiplatform-key-${var.environment}"
  enabled = true
}

# Usage Plan
resource "aws_api_gateway_usage_plan" "platform" {
  name = "lerma-aiplatform-usage-plan-${var.environment}"

  api_stages {
    api_id = aws_api_gateway_rest_api.platform.id
    stage  = aws_api_gateway_stage.platform.stage_name
  }

  throttle_settings {
    burst_limit = 10
    rate_limit  = 5
  }

  quota_settings {
    limit  = 1000
    period = "MONTH"
  }
}

# Associate API Key with Usage Plan
resource "aws_api_gateway_usage_plan_key" "platform" {
  key_id        = aws_api_gateway_api_key.platform.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.platform.id
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/lerma-aiplatform-${var.environment}"
  retention_in_days = 30
}
