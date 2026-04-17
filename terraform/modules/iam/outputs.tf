output "intake_lambda_role_arn" {
  description = "ARN of the intake Lambda IAM role"
  value       = aws_iam_role.intake_lambda.arn
}

output "content_generator_lambda_role_arn" {
  description = "ARN of the content generator Lambda IAM role"
  value       = aws_iam_role.content_generator_lambda.arn
}

output "step_functions_role_arn" {
  description = "ARN of the Step Functions IAM role"
  value       = aws_iam_role.step_functions.arn
}