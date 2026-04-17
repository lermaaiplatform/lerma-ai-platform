output "daily_content_rule_arn" {
  description = "ARN of the daily content generation EventBridge rule"
  value       = aws_cloudwatch_event_rule.daily_content.arn
}

output "weekly_digest_rule_arn" {
  description = "ARN of the weekly digest EventBridge rule"
  value       = aws_cloudwatch_event_rule.weekly_digest.arn
}