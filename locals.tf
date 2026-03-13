locals {
  #---------------------------------------
  # Deployment Mode
  #---------------------------------------
  is_organization  = var.deployment_mode == "organization"
  is_account_group = var.deployment_mode == "account_group"
  has_stackset     = local.is_organization || local.is_account_group
  needs_org_api    = local.is_organization
  ou_name_suffix   = local.is_account_group ? "-${var.organizational_unit_id}" : ""

  #---------------------------------------
  # Module Conditionals
  #---------------------------------------
  organizational_unit_id = (
    var.organizational_unit_id != ""
      ? var.organizational_unit_id
      : (local.needs_org_api ? module.org_info[0].root_id : "")
  )

  scanner_enabled = var.enable_modules.dspm || var.enable_modules.registry || var.enable_modules.serverless

  scanner_principals = compact([
    var.enable_modules.dspm ? "arn:aws:iam::${var.outpost_account_id}:role/dspm_scanner" : "",
    var.enable_modules.registry ? "arn:aws:iam::${var.outpost_account_id}:role/registry_scanner" : "",
    var.enable_modules.serverless ? "arn:aws:iam::${var.outpost_account_id}:role/scanner_of_serverless" : "",
  ])

  #---------------------------------------
  # Template Configuration (dynamic)
  #---------------------------------------
  template_version = merge(
    {
      "DISCOVERY-assets_discovery"                                                                                                  = var.template_versions.discovery
      (local.is_organization ? "BASE-base_organization" : local.is_account_group ? "BASE-base_account_group" : "BASE-base_account") = var.template_versions.base
    },
    var.enable_modules.audit_logs ? { "AUDIT_LOGS-audit_logs_byob" = var.template_versions.audit_logs } : {},
    var.enable_modules.ads ? { "ADS-agentless_disk_scanning" = var.template_versions.ads } : {},
    var.enable_modules.dspm ? { "DSPM-data_security_posture_management" = var.template_versions.dspm } : {},
    local.scanner_enabled ? { "OUTPOST_SCANNER-outpost_scanner" = var.template_versions.outpost_scanner } : {},
    var.enable_modules.registry ? { "REGISTRY-registry_scanning" = var.template_versions.registry } : {},
    var.enable_modules.serverless ? { "SERVERLESS-serverless_scanning" = var.template_versions.serverless } : {},
    var.enable_modules.automation ? { "AUTOMATION-automation" = var.template_versions.automation } : {},
  )

  #---------------------------------------
  # Resource Names
  #---------------------------------------

  platform_role_name = coalesce(
    var.resource_names.platform_role,
    "CortexPlatformRole-${var.resource_suffix}${local.ou_name_suffix}"
  )

  scanner_role_name = coalesce(
    var.resource_names.scanner_role,
    "CortexPlatformScannerRole-${var.resource_suffix}${local.ou_name_suffix}"
  )

  cloudtrail_role_name = coalesce(
    var.resource_names.cloudtrail_role,
    "cortex-logs-ingestion-access-${var.resource_suffix}${local.ou_name_suffix}"
  )

  sqs_queue_name = coalesce(
    var.resource_names.sqs_queue,
    "cortex-ct-logs-queue-byob-${data.aws_caller_identity.current.account_id}-${var.resource_suffix}${local.ou_name_suffix}"
  )

  ads_policy_name = coalesce(
    var.resource_names.ads_policy,
    "Cortex-ADS-Policy-${var.resource_suffix}${local.ou_name_suffix}"
  )

  discovery_policy_name = coalesce(
    var.resource_names.discovery_policy,
    "Cortex-DISCOVERY-Policy-${var.resource_suffix}${local.ou_name_suffix}"
  )

  automation_policy_name = coalesce(
    var.resource_names.automation_policy,
    "Cortex-Automation-Policy-${var.resource_suffix}${local.ou_name_suffix}"
  )

  dspm_policy_name = coalesce(
    var.resource_names.dspm_policy,
    "Cortex-DSPM-Policy-${var.resource_suffix}${local.ou_name_suffix}"
  )

  lambda_role_name = coalesce(
    var.resource_names.lambda_role,
    "CortexLambdaExecutionRole-${var.resource_suffix}${local.ou_name_suffix}"
  )

  lambda_function_name = coalesce(
    var.resource_names.lambda_function,
    "CortexConnectorRegistration-${var.resource_suffix}${local.ou_name_suffix}"
  )

  lambda_sg_name = coalesce(
    var.resource_names.lambda_sg,
    "CortexLambdaSG-${var.resource_suffix}${local.ou_name_suffix}"
  )

  stack_set_name = coalesce(
    var.resource_names.stack_set,
    "CortexPlatformRoleStackSetMember-${var.resource_suffix}${local.ou_name_suffix}"
  )

  #---------------------------------------
  # Conditionals
  #---------------------------------------
  cloudtrail_enabled = var.enable_modules.audit_logs && var.cloudtrail_logs_bucket != "" && var.cloudtrail_sns_arn != ""
  has_kms_key        = var.cloudtrail_kms_arn != ""

  #---------------------------------------
  # Account Filtering
  #---------------------------------------
  account_filter_type = local.has_stackset ? (
    length(var.include_account_ids) > 0 ? "INTERSECTION" :
    length(var.exclude_account_ids) > 0 ? "DIFFERENCE" :
    null
  ) : null

  account_filter_ids = local.has_stackset ? (
    length(var.include_account_ids) > 0 ? var.include_account_ids :
    length(var.exclude_account_ids) > 0 ? var.exclude_account_ids :
    null
  ) : null

  #---------------------------------------
  # Tags
  #---------------------------------------
  tags = merge(var.additional_tags, { managed_by = "paloaltonetworks" })
}
