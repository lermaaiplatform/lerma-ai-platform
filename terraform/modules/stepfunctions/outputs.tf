output "intake_workflow_arn" {
  description = "ARN of the intake workflow state machine"
  value       = aws_sfn_state_machine.intake_workflow.arn
}

output "intake_workflow_name" {
  description = "Name of the intake workflow state machine"
  value       = aws_sfn_state_machine.intake_workflow.name
}

output "content_workflow_arn" {
  description = "ARN of the content generation workflow state machine"
  value       = aws_sfn_state_machine.content_workflow.arn
}

output "content_workflow_name" {
  description = "Name of the content generation workflow state machine"
  value       = aws_sfn_state_machine.content_workflow.name
}