terraform {
  required_version = "~> 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "lerma-aiplatform-tfstate-2026"
    key            = "execcoach/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "lerma-aiplatform-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Project     = "lerma-ai-platform"
      Environment = "poc"
      ManagedBy   = "terraform"
      Owner       = "jonathan-lerma"
    }
  }
}

module "platform" {
  source      = "./modules/platform"
  environment = "poc"
  project     = "lerma-ai-platform"
}

module "iam" {
  source              = "./modules/iam"
  environment         = "poc"
  platform_bucket_arn = module.platform.platform_bucket_arn
  dynamodb_table_arn  = module.platform.dynamodb_table_arn
}

module "lambda" {
  source                            = "./modules/lambda"
  environment                       = "poc"
  platform_bucket_name              = module.platform.platform_bucket_name
  dynamodb_table_name               = module.platform.dynamodb_table_name
  intake_lambda_role_arn            = module.iam.intake_lambda_role_arn
  content_generator_lambda_role_arn = module.iam.content_generator_lambda_role_arn
  tenant_id                         = "tenant-001"
  from_email                        = var.tenant_001_email
  notify_email                      = var.tenant_001_email
}

module "apigateway" {
  source              = "./modules/apigateway"
  environment         = "poc"
  intake_handler_arn  = module.lambda.intake_handler_arn
  intake_handler_name = module.lambda.intake_handler_name
}

module "ses" {
  source      = "./modules/ses"
  environment = "poc"
  from_email  = var.tenant_001_email
}

module "eventbridge" {
  source                 = "./modules/eventbridge"
  environment            = "poc"
  content_generator_arn  = module.lambda.content_generator_arn
  content_generator_name = module.lambda.content_generator_name
  tenant_id              = "tenant-001"
}

module "datalake" {
  source               = "./modules/datalake"
  environment          = "poc"
  platform_bucket_name = module.platform.platform_bucket_name
  platform_bucket_arn  = module.platform.platform_bucket_arn
  tenant_ids           = ["tenant-001"]
}

module "bedrock" {
  source               = "./modules/bedrock"
  environment          = "poc"
  tenant_id            = "tenant-001"
  platform_bucket_name = module.platform.platform_bucket_name
  platform_bucket_arn  = module.platform.platform_bucket_arn
}

module "frontend" {
  source          = "./modules/frontend"
  environment     = "poc"
  tenant_id       = "tenant-001"
  api_gateway_url = "https://40q0x4hsii.execute-api.us-east-2.amazonaws.com/poc"
}

module "stepfunctions" {
  source                  = "./modules/stepfunctions"
  environment             = "poc"
  tenant_id               = "tenant-001"
  intake_handler_arn      = module.lambda.intake_handler_arn
  content_generator_arn   = module.lambda.content_generator_arn
  step_functions_role_arn = module.iam.step_functions_role_arn
}

module "tenant_001" {
  source               = "./modules/tenant"
  tenant_id            = "tenant-001"
  tenant_name          = "fathers-coaching-business"
  tenant_email         = var.tenant_001_email
  platform_bucket      = module.platform.platform_bucket_name
  dynamodb_table       = module.platform.dynamodb_table_name
  cognito_user_pool_id = module.platform.cognito_user_pool_id
}