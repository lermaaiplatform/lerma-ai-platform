terraform {
  required_version = "~> 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
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

module "tenant_001" {
  source               = "./modules/tenant"
  tenant_id            = "tenant-001"
  tenant_name          = "fathers-coaching-business"
  tenant_email         = var.tenant_001_email
  platform_bucket      = module.platform.platform_bucket_name
  dynamodb_table       = module.platform.dynamodb_table_name
  cognito_user_pool_id = module.platform.cognito_user_pool_id
}