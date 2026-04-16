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