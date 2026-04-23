output "intake_handler_arn" {
  description = "ARN of the intake handler Lambda function"
  value       = aws_lambda_function.intake_handler.arn
}

output "intake_handler_name" {
  description = "Name of the intake handler Lambda function"
  value       = aws_lambda_function.intake_handler.function_name
}

output "content_generator_arn" {
  description = "ARN of the content generator Lambda function"
  value       = aws_lambda_function.content_generator.arn
}

output "content_generator_name" {
  description = "Name of the content generator Lambda function"
  value       = aws_lambda_function.content_generator.function_name
}

output "watchlist_fetcher_arn" {
  description = "ARN of the watchlist fetcher Lambda function"
  value       = aws_lambda_function.watchlist_fetcher.arn
}

output "watchlist_fetcher_name" {
  description = "Name of the watchlist fetcher Lambda function"
  value       = aws_lambda_function.watchlist_fetcher.function_name
}