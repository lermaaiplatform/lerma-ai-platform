# Lake Formation Settings
resource "aws_lakeformation_data_lake_settings" "platform" {
  admins = [data.aws_caller_identity.current.arn]
}

# Current AWS account identity
data "aws_caller_identity" "current" {}

# Lake Formation Resource: Register S3 bucket
resource "aws_lakeformation_resource" "platform_bucket" {
  arn = var.platform_bucket_arn
}

# Glue Database per tenant
resource "aws_glue_catalog_database" "tenant" {
  for_each = toset(var.tenant_ids)

  name        = "lerma_platform_${replace(each.key, "-", "_")}_${var.environment}"
  description = "Glue catalog database for ${each.key}"
}

# IAM Role for Glue Crawler
data "aws_iam_policy_document" "glue_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue_crawler" {
  name               = "lerma-platform-glue-crawler-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.glue_trust.json
}

resource "aws_iam_role_policy" "glue_crawler_policy" {
  name = "glue-crawler-policy"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.platform_bucket_arn,
          "${var.platform_bucket_arn}/*"
        ]
      },
      {
        Sid    = "GlueAccess"
        Effect = "Allow"
        Action = [
          "glue:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "LakeFormation"
        Effect = "Allow"
        Action = [
          "lakeformation:GetDataAccess"
        ]
        Resource = "*"
      }
    ]
  })
}

# Glue Crawler per tenant
resource "aws_glue_crawler" "tenant" {
  for_each = toset(var.tenant_ids)

  name          = "lerma-platform-crawler-${each.key}-${var.environment}"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.tenant[each.key].name
  schedule      = "cron(0 6 ? * SUN *)"

  s3_target {
    path = "s3://${var.platform_bucket_name}/coaches/${each.key}/"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })
}

# Athena Workgroup
resource "aws_athena_workgroup" "platform" {
  name        = "lerma-aiplatform-${var.environment}"
  description = "Athena workgroup for Lerma AI Platform analytics"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.platform_bucket_name}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}

# Lake Formation permissions for Glue crawler role
resource "aws_lakeformation_permissions" "glue_crawler_database" {
  for_each = toset(var.tenant_ids)

  principal = aws_iam_role.glue_crawler.arn

  permissions = [
    "CREATE_TABLE",
    "DESCRIBE",
    "ALTER"
  ]

  database {
    name = aws_glue_catalog_database.tenant[each.key].name
  }
}

resource "aws_lakeformation_permissions" "glue_crawler_s3" {
  principal   = aws_iam_role.glue_crawler.arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = var.platform_bucket_arn
  }
}

# CloudWatch Log Group for Glue
resource "aws_cloudwatch_log_group" "glue" {
  name              = "/aws/glue/lerma-aiplatform-${var.environment}"
  retention_in_days = 30
}