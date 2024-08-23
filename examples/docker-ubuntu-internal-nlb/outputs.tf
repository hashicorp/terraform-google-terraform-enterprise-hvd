output "tfe_fqdn" {
  value       = module.tfe_fdo_default.url
  description = "Terraform-Enterprise URL based on `tfe_fqdn` input"
}

output "tfe_retrieve_iact" {
  value       = var.tfe_iact_subnets != "" ? "${module.tfe_fdo_default.tfe_retrieve_iact}" : null
  description = "Terraform-Enterprise URL to retrieve initial user token based on `tfe_fqdn` input, and `tfe_iact_subnets` is set"
}
