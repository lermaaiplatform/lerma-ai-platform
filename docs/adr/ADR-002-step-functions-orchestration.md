# ADR-002: Step Functions for Workflow Orchestration

## Date
April 2026

## Status
Accepted

## Context
The platform requires multi-step AI workflows including
tenant onboarding, content generation pipelines, and
prospect intake processing. Two options were evaluated:
direct Lambda-to-Lambda invocation and AWS Step Functions.

## Decision
Use AWS Step Functions Standard Workflows as the
orchestration layer for all multi-step processes.

## Reasons
- Every workflow execution is automatically logged
  with full input, output, and timing at each state
- Built-in retry logic with exponential backoff
  requires no custom Lambda code
- Visual workflow editor aids debugging and
  stakeholder communication
- Execution history provides audit trail required
  for enterprise compliance
- Error handling is declarative not embedded in
  application code

## Consequences
- Additional Terraform resources required per workflow
- Step Functions pricing applies per state transition
- Team needs familiarity with Amazon States Language
- Slightly more complex initial setup than direct
  Lambda invocation
