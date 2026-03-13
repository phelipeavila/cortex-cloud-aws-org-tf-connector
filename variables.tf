#---------------------------------------
# Deployment Mode
#---------------------------------------

variable "deployment_mode" {
  description = <<-EOT
    Deployment scope:
      "organization"  - Org root or OU with Organizations API access. Uses StackSet. Auto-detects org root if organizational_unit_id is empty.
      "account_group" - Specific OU without Organizations API. Uses StackSet. Appends OU ID to resource names.
      "account"       - Single account. No StackSet, no Organizations API.
  EOT
  type        = string
  default     = "organization"
  validation {
    condition     = contains(["organization", "account_group", "account"], var.deployment_mode)
    error_message = "deployment_mode must be 'organization', 'account_group', or 'account'."
  }
}

#---------------------------------------
# Palo Alto Networks Infrastructure
#---------------------------------------

variable "outpost_role_arn" {
  description = "Assume-role principal ARN used by Cortex to access your account"
  type        = string
}

variable "outpost_account_id" {
  description = "AWS account ID of the Cortex outpost"
  type        = string
}

variable "kms_account_ads" {
  description = "AWS account ID that owns the KMS keys for ADS scanning. Required when enable_modules.ads is true."
  type        = string
  default     = ""
}

variable "kms_account_dspm" {
  description = "AWS account ID that owns the KMS keys for DSPM scanning. Required when enable_modules.dspm is true."
  type        = string
  default     = ""
}

variable "collector_service_account" {
  description = "Google service account ID used by the AWS CloudTrail collector. Required when enable_modules.audit_logs is true."
  type        = string
  default     = ""
}

variable "audience" {
  description = "Audience value for the federated (Google) principal on the CloudTrail reader role. Required when enable_modules.audit_logs is true."
  type        = string
  default     = ""
}

variable "copy_snapshot_suffix" {
  description = "Suffix pattern for ADS copy-snapshot resource ARNs. Required when enable_modules.ads is true."
  type        = string
  default     = ""
}

#---------------------------------------
# Template Versions
#---------------------------------------

variable "template_versions" {
  description = "Version strings for each Cortex module template, sent during connector registration."
  type = object({
    discovery       = string
    base            = string
    audit_logs      = string
    ads             = string
    dspm            = string
    outpost_scanner = string
    registry        = string
    serverless      = string
    automation      = string
  })
}

#---------------------------------------
# Core Cortex Parameters
#---------------------------------------

variable "external_id" {
  description = "External ID for the IAM role trust relationship"
  type        = string
}

variable "template_id" {
  description = "Unique template ID from Cortex XDR"
  type        = string
  validation {
    condition     = can(regex("^[a-f0-9]{32}$", var.template_id))
    error_message = "template_id must be a 32-character hex string."
  }
}

variable "upload_output_url" {
  description = "Signed URL for registering the connector with Cortex XDR"
  type        = string
  sensitive   = true
}

variable "connector_id" {
  description = "Optional connector ID"
  type        = string
  default     = ""
}

#---------------------------------------
# Organization Configuration
#---------------------------------------

variable "organizational_unit_id" {
  description = "OU ID to deploy the StackSet to (e.g., r-xxxx for the org root, ou-xxxx-xxxxxxxx for a specific OU). When empty, auto-detects the organization root."
  type        = string
  default     = ""
}

#---------------------------------------
# CloudTrail Integration
#---------------------------------------

variable "cloudtrail_logs_bucket" {
  description = "CloudTrail Logs S3 bucket name"
  type        = string
  default     = ""
}

variable "cloudtrail_sns_arn" {
  description = "CloudTrail SNS topic ARN"
  type        = string
  default     = ""
}

variable "cloudtrail_kms_arn" {
  description = "CloudTrail KMS key ARN (optional)"
  type        = string
  default     = ""
}

#---------------------------------------
# Resource Naming
#---------------------------------------

variable "resource_suffix" {
  description = "Suffix for default resource names. Extracted from original CloudFormation template."
  type        = string
  default     = "m-o-1006371815406"
}

variable "resource_names" {
  description = "Override individual resource names. Takes precedence over resource_suffix when set."
  type = object({
    platform_role     = optional(string)
    scanner_role      = optional(string)
    cloudtrail_role   = optional(string)
    sqs_queue         = optional(string)
    ads_policy        = optional(string)
    discovery_policy  = optional(string)
    automation_policy = optional(string)
    dspm_policy       = optional(string)
    lambda_role       = optional(string)
    lambda_function   = optional(string)
    lambda_sg         = optional(string)
    stack_set         = optional(string)
  })
  default = {}
}

#---------------------------------------
# VPC Configuration (Optional)
#---------------------------------------

variable "deploy_in_vpc" {
  description = "Deploy the registration Lambda inside a VPC. Requires vpc_subnet_ids and at least one of vpc_id or vpc_security_group_ids."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "ID of an existing VPC. When provided, a managed Security Group with HTTPS egress is created for the Lambda."
  type        = string
  default     = ""
}

variable "vpc_subnet_ids" {
  description = "List of private subnet IDs for Lambda ENI placement. Required when deploy_in_vpc is true."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.deploy_in_vpc || length(var.vpc_subnet_ids) > 0
    error_message = "vpc_subnet_ids must not be empty when deploy_in_vpc is true."
  }
}

variable "vpc_security_group_ids" {
  description = "Optional list of existing Security Group IDs to attach to the Lambda. If omitted, vpc_id must be set so a managed SG can be created."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.deploy_in_vpc || length(var.vpc_security_group_ids) > 0 || var.vpc_id != ""
    error_message = "When deploy_in_vpc is true, at least one of vpc_id or vpc_security_group_ids must be provided."
  }
}

#---------------------------------------
# Module Toggles
#---------------------------------------

variable "enable_modules" {
  description = "Toggle Cortex modules on/off. Each matches a CF template variant from org-cf-connector/original/."
  type = object({
    audit_logs = optional(bool, true)
    ads        = optional(bool, false)
    dspm       = optional(bool, false)
    registry   = optional(bool, false)
    serverless = optional(bool, false)
    automation = optional(bool, false)
  })
  default = {}
}

#---------------------------------------
# Account Filtering
#---------------------------------------

variable "include_account_ids" {
  description = "Deploy the StackSet ONLY to these member accounts. Leave empty to deploy to all accounts in the OU. Cannot be used together with exclude_account_ids."
  type        = list(string)
  default     = []
}

variable "exclude_account_ids" {
  description = "Deploy the StackSet to all member accounts EXCEPT these. Leave empty to deploy to all accounts in the OU. Cannot be used together with include_account_ids."
  type        = list(string)
  default     = []
}

#---------------------------------------
# Additional Configuration
#---------------------------------------

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

#---------------------------------------
# Cross-variable validation
#---------------------------------------

check "account_filter_mutual_exclusion" {
  assert {
    condition     = length(var.include_account_ids) == 0 || length(var.exclude_account_ids) == 0
    error_message = "Only one of include_account_ids or exclude_account_ids can be set, not both."
  }
}

check "ads_requirements" {
  assert {
    condition     = !var.enable_modules.ads || var.kms_account_ads != ""
    error_message = "kms_account_ads is required when enable_modules.ads is true."
  }

  assert {
    condition     = !var.enable_modules.ads || var.copy_snapshot_suffix != ""
    error_message = "copy_snapshot_suffix is required when enable_modules.ads is true."
  }
}

check "dspm_requirements" {
  assert {
    condition     = !var.enable_modules.dspm || var.kms_account_dspm != ""
    error_message = "kms_account_dspm is required when enable_modules.dspm is true."
  }
}

check "audit_logs_requirements" {
  assert {
    condition     = !var.enable_modules.audit_logs || var.collector_service_account != ""
    error_message = "collector_service_account is required when enable_modules.audit_logs is true."
  }

  assert {
    condition     = !var.enable_modules.audit_logs || var.audience != ""
    error_message = "audience is required when enable_modules.audit_logs is true."
  }
}

check "account_group_requires_ou_id" {
  assert {
    condition     = var.deployment_mode != "account_group" || can(regex("^ou-", var.organizational_unit_id))
    error_message = "organizational_unit_id is required and must start with 'ou-' when deployment_mode is 'account_group'."
  }
}

check "account_mode_no_stackset_vars" {
  assert {
    condition = var.deployment_mode != "account" || (
      var.organizational_unit_id == "" &&
      length(var.include_account_ids) == 0 &&
      length(var.exclude_account_ids) == 0
    )
    error_message = "organizational_unit_id, include_account_ids, and exclude_account_ids are not applicable when deployment_mode is 'account'."
  }
}
