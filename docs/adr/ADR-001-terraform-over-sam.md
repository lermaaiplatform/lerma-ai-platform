# ADR-001: Terraform over AWS SAM

## Date
April 2026

## Status
Accepted

## Context
This platform requires infrastructure provisioning across
multiple AWS services including Lambda, API Gateway,
DynamoDB, S3, Cognito, Bedrock, SES, Step Functions,
and EventBridge. Two primary IaC options were evaluated:
AWS SAM and Terraform.

## Decision
Use Terraform 1.14.8 with the AWS provider 6.x.

## Reasons
- Terraform is cloud-agnostic supporting future
  multi-cloud requirements across AWS and Azure
- Broader enterprise adoption makes this skill
  more transferable across roles and organizations
- Explicit resource model provides clearer visibility
  into what is being provisioned
- Module system supports the multi-tenant architecture
  pattern this platform requires
- SAM abstracts too much for a platform needing
  precise control over every resource configuration

## Consequences
- More verbose configuration than SAM for Lambda
- State must be managed explicitly in S3
- Slightly longer initial setup time
- All contributors need Terraform familiarity
