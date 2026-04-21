output "glue_database_names" {
  description = "Names of the Glue catalog databases per tenant"
  value       = { for k, v in aws_glue_catalog_database.tenant : k => v.name }
}

output "glue_crawler_names" {
  description = "Names of the Glue crawlers per tenant"
  value       = { for k, v in aws_glue_crawler.tenant : k => v.name }
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.platform.name
}

output "glue_crawler_role_arn" {
  description = "ARN of the Glue crawler IAM role"
  value       = aws_iam_role.glue_crawler.arn
}