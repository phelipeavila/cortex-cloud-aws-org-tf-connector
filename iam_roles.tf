#---------------------------------------
# Roles
#---------------------------------------

resource "aws_iam_role" "cortex_platform" {
  name = local.platform_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [var.outpost_role_arn]
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "export.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cortex_platform_managed" {
  for_each = toset([
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonMemoryDBReadOnlyAccess",
    "arn:aws:iam::aws:policy/SecurityAudit",
    "arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess",
    "arn:aws:iam::aws:policy/AWSOrganizationsReadOnlyAccess"
  ])
  role       = aws_iam_role.cortex_platform.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "cortex_platform_custom" {
  for_each = merge(
    { discovery = aws_iam_policy.cortex_discovery.arn },
    var.enable_modules.ads ? { ads = aws_iam_policy.cortex_ads[0].arn } : {},
    var.enable_modules.dspm ? { dspm = aws_iam_policy.cortex_dspm[0].arn } : {},
    var.enable_modules.automation ? { automation = aws_iam_policy.cortex_automation[0].arn } : {},
  )
  role       = aws_iam_role.cortex_platform.name
  policy_arn = each.value
}

resource "aws_iam_role" "cortex_scanner" {
  count = local.scanner_enabled ? 1 : 0
  name  = local.scanner_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.scanner_principals
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cortex_scanner_managed" {
  for_each = local.scanner_enabled ? toset([
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonMemoryDBReadOnlyAccess"
  ]) : toset([])
  role       = aws_iam_role.cortex_scanner[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "cortex_scanner_dspm" {
  count = var.enable_modules.dspm ? 1 : 0
  name  = "Cortex-DSPM-Scanner-Policy"
  role  = aws_iam_role.cortex_scanner[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:PutObject*", "s3:List*", "s3:Get*", "s3:DeleteObject*"]
        Resource = [
          "arn:aws:s3:::cortex-artifact*",
          "arn:aws:s3:::cortex-artifact*/*"
        ]
      },
      {
        Sid      = "DescribeAndGenerateKeyWithoutPlaintext"
        Effect   = "Allow"
        Action   = ["kms:DescribeKey", "kms:GenerateDataKeyWithoutPlaintext"]
        Resource = "arn:${data.aws_partition.current.partition}:kms:*:${var.kms_account_dspm}:key/*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.scanner_role_name}*"
      },
      {
        Sid      = "DynamoDBAndCloudWatchAccess"
        Effect   = "Allow"
        Action   = ["dynamodb:DescribeTable", "dynamodb:Scan", "cloudwatch:GetMetricStatistics"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cortex_scanner_ecr" {
  count = var.enable_modules.registry ? 1 : 0
  name  = "ECRAccessPolicy"
  role  = aws_iam_role.cortex_scanner[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAccessSid"
        Effect   = "Allow"
        Action   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:GetAuthorizationToken"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cortex_scanner_lambda" {
  count = var.enable_modules.serverless ? 1 : 0
  name  = "LAMBDAAccessPolicy"
  role  = aws_iam_role.cortex_scanner[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "LAMBDAAccessSid"
        Effect   = "Allow"
        Action   = ["lambda:GetFunction", "lambda:GetFunctionConfiguration", "lambda:GetLayerVersion", "iam:GetRole"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "cloudtrail_reader" {
  count = local.cloudtrail_enabled ? 1 : 0
  name  = local.cloudtrail_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = "accounts.google.com" }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "accounts.google.com:oaud" = var.audience
            "accounts.google.com:sub"  = var.collector_service_account
          }
        }
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "cloudtrail_reader_access" {
  count = local.cloudtrail_enabled ? 1 : 0
  name  = "CloudTrailReadAccessPolicy"
  role  = aws_iam_role.cloudtrail_reader[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = ["s3:GetObject", "s3:ListBucket"]
          Resource = [
            "arn:aws:s3:::${var.cloudtrail_logs_bucket}",
            "arn:aws:s3:::${var.cloudtrail_logs_bucket}/*"
          ]
        },
        {
          Effect   = "Allow"
          Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
          Resource = aws_sqs_queue.cloudtrail_logs[0].arn
        }
      ],
      local.has_kms_key ? [{ Effect = "Allow", Action = ["kms:Decrypt"], Resource = var.cloudtrail_kms_arn }] : []
    )
  })
}
