output "root_id" {
  description = "Root ID of the AWS Organization"
  value       = data.aws_organizations_organization.current.roots[0].id
}

output "org_id" {
  description = "Organization ID (o-xxxxxxxxxx)"
  value       = data.aws_organizations_organization.current.id
}
