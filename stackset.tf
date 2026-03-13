#---------------------------------------
# StackSet for Member Account Roles
#---------------------------------------

locals {
  #---------------------------------------
  # StackSet Parameters
  #---------------------------------------
  stackset_base_parameters = {
    CortexPlatformRoleName = local.platform_role_name
    ExternalID             = var.external_id
    OutpostRoleArn         = var.outpost_role_arn
  }

  stackset_ads_parameters = var.enable_modules.ads ? {
    OutpostAccountId   = var.outpost_account_id
    KmsAccountADS      = var.kms_account_ads
    CopySnapshotSuffix = var.copy_snapshot_suffix
  } : {}

  stackset_dspm_parameters = var.enable_modules.dspm ? {
    MTKmsAccountDSPM = var.kms_account_dspm
  } : {}

  stackset_scanner_parameters = local.scanner_enabled ? {
    CortexPlatformScannerRoleName = var.resource_names.scanner_role != null ? var.resource_names.scanner_role : "CortexPlatformScannerRole"
  } : {}

  stackset_parameters = merge(
    local.stackset_base_parameters,
    local.stackset_ads_parameters,
    local.stackset_dspm_parameters,
    local.stackset_scanner_parameters,
  )
}

resource "aws_cloudformation_stack_set" "cortex_member_roles" {
  count            = local.has_stackset ? 1 : 0
  name             = local.stack_set_name
  permission_model = "SERVICE_MANAGED"
  capabilities     = ["CAPABILITY_NAMED_IAM"]

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  operation_preferences {
    failure_tolerance_percentage = 100
    region_concurrency_type      = "PARALLEL"
  }

  parameters = local.stackset_parameters

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Cortex XDR Cloud Role to set read permissions"
    Parameters               = local.cf_parameters
    Resources                = local.cf_resources
    Outputs = {
      CORTEXXDRARN = {
        Value       = { "Fn::GetAtt" = ["CortexPlatformRole", "Arn"] }
        Description = "Role ARN to configure within Cortex Platform Account Member Setup"
      }
    }
  })
}

resource "aws_cloudformation_stack_set_instance" "cortex_member_instances" {
  count = local.has_stackset ? 1 : 0
  deployment_targets {
    organizational_unit_ids = [local.organizational_unit_id]
    account_filter_type     = local.account_filter_type
    accounts                = local.account_filter_ids
  }
  region         = data.aws_region.current.name
  stack_set_name = aws_cloudformation_stack_set.cortex_member_roles[0].name
}
