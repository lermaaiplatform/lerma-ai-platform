# Data source for current AWS account
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM Role for Bedrock Knowledge Base
data "aws_iam_policy_document" "bedrock_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "bedrock_kb" {
  name               = "lerma-platform-bedrock-kb-${var.tenant_id}-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.bedrock_trust.json
}

resource "aws_iam_role_policy" "bedrock_kb_policy" {
  name = "bedrock-kb-policy"
  role = aws_iam_role.bedrock_kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3KnowledgeBaseAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.platform_bucket_arn,
          "${var.platform_bucket_arn}/*"
        ]
      },
      {
        Sid    = "BedrockEmbeddings"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v2:0"
      },
      {
        Sid    = "S3VectorsAccess"
        Effect = "Allow"
        Action = [
          "s3vectors:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# S3 Vectors Bucket for Knowledge Base embeddings
resource "aws_s3vectors_vector_bucket" "kb" {
  vector_bucket_name = "lerma-platform-vectors-${var.tenant_id}-${var.environment}"
}

# Bedrock Knowledge Base
resource "aws_bedrockagent_knowledge_base" "tenant" {
  name        = "lerma-platform-kb-${var.tenant_id}-${var.environment}"
  description = "Knowledge base for ${var.tenant_id} containing coaching methodology and brand voice"
  role_arn    = aws_iam_role.bedrock_kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }

  storage_configuration {
    type = "S3_VECTORS"
    s3_vectors_configuration {
      index_name        = "lerma-platform-index-${var.tenant_id}-${var.environment}"
      vector_bucket_arn = "arn:aws:s3vectors:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:bucket/lerma-platform-vectors-${var.tenant_id}-${var.environment}"
    }
  }
}

# Bedrock Knowledge Base Data Source
resource "aws_bedrockagent_data_source" "tenant_kb" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.tenant.id
  name              = "lerma-platform-ds-${var.tenant_id}-${var.environment}"
  description       = "S3 data source for ${var.tenant_id} knowledge base"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = var.platform_bucket_arn
      inclusion_prefixes = ["coaches/${var.tenant_id}/knowledge-base/"]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 300
        overlap_percentage = 20
      }
    }
  }
}

# Bedrock Guardrail
resource "aws_bedrock_guardrail" "tenant" {
  name                      = "lerma-platform-guardrail-${var.tenant_id}-${var.environment}"
  description               = "Guardrails for ${var.tenant_id} content generation"
  blocked_input_messaging   = "This request cannot be processed."
  blocked_outputs_messaging = "This response cannot be provided."

  topic_policy_config {
    topics_config {
      name       = "medical-advice"
      definition = "Any specific medical advice, diagnosis, or treatment recommendations"
      examples   = ["You should take this medication", "Your diagnosis is"]
      type       = "DENY"
    }
    topics_config {
      name       = "competitor-promotion"
      definition = "Promotion of competing coaching services or brands"
      examples   = ["You should use another coaching service"]
      type       = "DENY"
    }
  }

  sensitive_information_policy_config {
    pii_entities_config {
      type   = "EMAIL"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "PHONE"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "NAME"
      action = "ANONYMIZE"
    }
  }

  word_policy_config {
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }
}
