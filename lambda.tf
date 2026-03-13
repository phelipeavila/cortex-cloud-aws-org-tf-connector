#---------------------------------------
# Lambda Execution Role
#---------------------------------------

resource "aws_iam_role" "lambda_execution" {
  name = local.lambda_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lambda_execution_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_execution_orgs" {
  count      = local.needs_org_api ? 1 : 0
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AWSOrganizationsReadOnlyAccess"
}

#---------------------------------------
# Optional VPC Resources
#---------------------------------------

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  count      = var.deploy_in_vpc ? 1 : 0
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_security_group" "lambda_vpc_sg" {
  count       = (var.deploy_in_vpc && var.vpc_id != "") ? 1 : 0
  name        = local.lambda_sg_name
  description = "Managed SG for Cortex registration Lambda - HTTPS egress only"
  vpc_id      = var.vpc_id
  tags        = local.tags
}

resource "aws_vpc_security_group_egress_rule" "lambda_https_out" {
  count             = (var.deploy_in_vpc && var.vpc_id != "") ? 1 : 0
  security_group_id = aws_security_group.lambda_vpc_sg[0].id
  description       = "Allow HTTPS egress to reach Google Cloud APIs for registration"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  tags              = local.tags
}

#---------------------------------------
# Lambda Function
#---------------------------------------

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_source"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "connector_registration" {
  function_name    = local.lambda_function_name
  role             = aws_iam_role.lambda_execution.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 75
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  tags             = local.tags

  dynamic "vpc_config" {
    for_each = var.deploy_in_vpc ? [1] : []
    content {
      subnet_ids = var.vpc_subnet_ids
      security_group_ids = concat(
        var.vpc_security_group_ids,
        aws_security_group.lambda_vpc_sg[*].id
      )
    }
  }
}

#---------------------------------------
# Connector Registration Invocation
#---------------------------------------

resource "aws_lambda_invocation" "register_connector" {
  function_name = aws_lambda_function.connector_registration.function_name

  input = jsonencode({
    AccountId       = data.aws_caller_identity.current.account_id
    RoleArn         = aws_iam_role.cortex_platform.arn
    ExternalID      = var.external_id
    TemplateId      = var.template_id
    UploadOutputUrl = var.upload_output_url
    TemplateVersion = local.template_version
    ConnectorId     = var.connector_id
    OrganizationId  = local.is_organization ? local.organizational_unit_id : ""
    AccountGroup    = local.is_account_group ? var.organizational_unit_id : ""
    NeedsOrgApi     = local.needs_org_api
    ModulePermissionScope = merge(
      {
        CortexCOMMONPolicyArns = [
          "arn:aws:iam::aws:policy/ReadOnlyAccess",
          "arn:aws:iam::aws:policy/AmazonMemoryDBReadOnlyAccess",
          "arn:aws:iam::aws:policy/SecurityAudit",
          "arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess",
          "arn:aws:iam::aws:policy/AWSOrganizationsReadOnlyAccess"
        ]
        CortexDISCOVERYPolicyArn = aws_iam_policy.cortex_discovery.arn
      },
      var.enable_modules.ads ? { CortexADSPolicyArn = aws_iam_policy.cortex_ads[0].arn } : {},
      var.enable_modules.dspm ? { CortexDSPMPolicyArn = aws_iam_policy.cortex_dspm[0].arn } : {},
      var.enable_modules.automation ? { CortexAutomationPolicyArn = aws_iam_policy.cortex_automation[0].arn } : {},
    )
    audit_logs_byob = local.cloudtrail_enabled ? {
      sqs_url  = aws_sqs_queue.cloudtrail_logs[0].id
      role_arn = aws_iam_role.cloudtrail_reader[0].arn
      audience = var.audience
    } : null
    outpost_scanner = local.scanner_enabled ? {
      outpost_scanner_role_arn = aws_iam_role.cortex_scanner[0].arn
    } : null
    provisioning_method = "CF"
  })

  lifecycle {
    ignore_changes = [input]
    postcondition {
      condition     = jsondecode(self.result)["Success"] == true
      error_message = "Connector registration failed: ${try(jsondecode(self.result)["error"], "unknown error")}"
    }
  }

  depends_on = [
    aws_iam_role.cortex_platform,
    aws_iam_role.cortex_scanner,
    aws_iam_role.cloudtrail_reader,
    aws_sqs_queue.cloudtrail_logs,
    aws_sns_topic_subscription.cloudtrail_to_sqs,
    aws_iam_role_policy_attachment.lambda_vpc_access,
    module.org_info
  ]
}
