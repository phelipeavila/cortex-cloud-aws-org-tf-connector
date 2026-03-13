output "cortex_platform_role_arn" {
  description = "ARN of the Cortex platform role in the management account"
  value       = aws_iam_role.cortex_platform.arn
}

output "cortex_scanner_role_arn" {
  description = "ARN of the Cortex scanner role in the management account"
  value       = local.scanner_enabled ? aws_iam_role.cortex_scanner[0].arn : null
}

output "cloudtrail_reader_role_arn" {
  description = "ARN of the CloudTrail reader role"
  value       = local.cloudtrail_enabled ? aws_iam_role.cloudtrail_reader[0].arn : null
}

output "sqs_queue_url" {
  description = "URL of the SQS queue for CloudTrail logs"
  value       = local.cloudtrail_enabled ? aws_sqs_queue.cloudtrail_logs[0].id : null
}

output "registration_result" {
  description = "Result from connector registration"
  value       = jsondecode(aws_lambda_invocation.register_connector.result)
}

output "stack_set_id" {
  description = "ID of the CloudFormation StackSet for member accounts (null in account mode)"
  value       = local.has_stackset ? aws_cloudformation_stack_set.cortex_member_roles[0].stack_set_id : null
}

output "deployment_mode" {
  description = "The deployment mode used (organization, account_group, or account)"
  value       = var.deployment_mode
}
