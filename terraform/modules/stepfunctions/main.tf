# Step Functions State Machine: Prospect Intake Workflow
resource "aws_sfn_state_machine" "intake_workflow" {
  name     = "lerma-platform-intake-workflow-${var.tenant_id}-${var.environment}"
  depends_on = [aws_cloudwatch_log_resource_policy.stepfunctions]
  role_arn = var.step_functions_role_arn

  definition = jsonencode({
    Comment = "Prospect intake workflow for ${var.tenant_id}"
    StartAt = "ValidatePayload"
    States = {
      ValidatePayload = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.intake_handler_arn
          "Payload.$" = "$"
        }
        ResultPath = "$.validation"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "IntakeFailed"
            ResultPath  = "$.error"
          }
        ]
        Next = "ScoreProspect"
      }

      ScoreProspect = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.intake_handler_arn
          Payload = {
            action = "SCORE_PROSPECT"
            "data.$" = "$.validation"
          }
        }
        ResultPath = "$.score"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "IntakeFailed"
            ResultPath  = "$.error"
          }
        ]
        Next = "CheckScore"
      }

      CheckScore = {
        Type    = "Choice"
        Choices = [
          {
            Variable      = "$.score.Payload.statusCode"
            NumericEquals = 200
            Next          = "GenerateFollowUp"
          }
        ]
        Default = "IntakeFailed"
      }

      GenerateFollowUp = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.content_generator_arn
          Payload = {
            action   = "GENERATE_FOLLOWUP"
            tenantId = var.tenant_id
            "data.$" = "$.score"
          }
        }
        ResultPath = "$.followup"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException"]
            IntervalSeconds = 5
            MaxAttempts     = 2
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "IntakeFailed"
            ResultPath  = "$.error"
          }
        ]
        Next = "IntakeComplete"
      }

      IntakeComplete = {
        Type   = "Succeed"
        Comment = "Prospect intake completed successfully"
      }

      IntakeFailed = {
        Type  = "Fail"
        Error = "IntakeWorkflowFailed"
        Cause = "Prospect intake workflow failed at one or more states"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.stepfunctions.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }
}

# Step Functions State Machine: Content Generation Workflow
resource "aws_sfn_state_machine" "content_workflow" {
  name     = "lerma-platform-content-workflow-${var.tenant_id}-${var.environment}"
  depends_on = [aws_cloudwatch_log_resource_policy.stepfunctions]
  role_arn = var.step_functions_role_arn

  definition = jsonencode({
    Comment = "Daily content generation workflow for ${var.tenant_id}"
    StartAt = "GeneratePost"
    States = {
      GeneratePost = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.content_generator_arn
          Payload = {
            action   = "GENERATE_POST"
            tenantId = var.tenant_id
            "eventType.$" = "$.eventType"
          }
        }
        ResultPath = "$.post"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException"]
            IntervalSeconds = 5
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "ContentFailed"
            ResultPath  = "$.error"
          }
        ]
        Next = "GenerateComments"
      }

      GenerateComments = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.content_generator_arn
          Payload = {
            action   = "GENERATE_COMMENTS"
            tenantId = var.tenant_id
            "data.$" = "$.post"
          }
        }
        ResultPath = "$.comments"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException"]
            IntervalSeconds = 5
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "ContentFailed"
            ResultPath  = "$.error"
          }
        ]
        Next = "SendDigest"
      }

      SendDigest = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.content_generator_arn
          Payload = {
            action   = "SEND_DIGEST"
            tenantId = var.tenant_id
            "post.$" = "$.post"
            "comments.$" = "$.comments"
          }
        }
        ResultPath = "$.digest"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException"]
            IntervalSeconds = 2
            MaxAttempts     = 2
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "ContentFailed"
            ResultPath  = "$.error"
          }
        ]
        Next = "ContentComplete"
      }

      ContentComplete = {
        Type    = "Succeed"
        Comment = "Content generation workflow completed successfully"
      }

      ContentFailed = {
        Type  = "Fail"
        Error = "ContentWorkflowFailed"
        Cause = "Content generation workflow failed at one or more states"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.stepfunctions.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "stepfunctions" {
  name              = "/aws/states/lerma-aiplatform-${var.tenant_id}-${var.environment}"
  retention_in_days = 30
}
# CloudWatch Log Resource Policy for Step Functions
resource "aws_cloudwatch_log_resource_policy" "stepfunctions" {
  policy_name = "lerma-platform-sfn-logs-${var.tenant_id}-${var.environment}"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowStepFunctionsLogs"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutLogEvents",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}
