# EventBridge Scheduled Rule: Daily Content Generation
resource "aws_cloudwatch_event_rule" "daily_content" {
  name                = "lerma-platform-daily-content-${var.environment}"
  description         = "Triggers content generator Lambda every weekday morning at 7AM ET"
  schedule_expression = "cron(0 12 ? * MON-FRI *)"
  state               = "ENABLED"
}

# EventBridge Target: Content Generator Lambda
resource "aws_cloudwatch_event_target" "content_generator" {
  rule      = aws_cloudwatch_event_rule.daily_content.name
  target_id = "ContentGeneratorLambda"
  arn       = var.content_generator_arn

  input = jsonencode({
    source    = "eventbridge.scheduled"
    tenantId  = var.tenant_id
    eventType = "DAILY_CONTENT_GENERATION"
  })
}

# Lambda Permission for EventBridge
resource "aws_lambda_permission" "eventbridge_content_generator" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.content_generator_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_content.arn
}

# EventBridge Scheduled Rule: Weekly Pipeline Digest
resource "aws_cloudwatch_event_rule" "weekly_digest" {
  name                = "lerma-platform-weekly-digest-${var.environment}"
  description         = "Triggers weekly pipeline summary every Monday at 8AM ET"
  schedule_expression = "cron(0 13 ? * MON *)"
  state               = "ENABLED"
}

# EventBridge Target: Content Generator Lambda for Weekly Digest
resource "aws_cloudwatch_event_target" "weekly_digest" {
  rule      = aws_cloudwatch_event_rule.weekly_digest.name
  target_id = "WeeklyDigestLambda"
  arn       = var.content_generator_arn

  input = jsonencode({
    source    = "eventbridge.scheduled"
    tenantId  = var.tenant_id
    eventType = "WEEKLY_PIPELINE_DIGEST"
  })
}

# CloudWatch Log Group for EventBridge
resource "aws_cloudwatch_log_group" "eventbridge" {
  name              = "/aws/eventbridge/lerma-aiplatform-${var.environment}"
  retention_in_days = 30
}