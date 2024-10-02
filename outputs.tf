# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


#------------------------------------------------------------------------------
# TFE URLs
#------------------------------------------------------------------------------
output "url" {
  value       = "https://${var.tfe_fqdn}"
  description = "URL of TFE application based on `tfe_fqdn` input."
}
output "tfe_fqdn" {
  value       = var.tfe_fqdn
  description = "`tfe_fqdn` input."
}

output "lb_ip_address" {
  value       = google_compute_address.tfe_frontend_lb.address
  description = "IP Address of the Load Balancer."
}


#------------------------------------------------------------------------------
# External Services
#------------------------------------------------------------------------------
# output "gcs_bucket_name" {
#   value       = length(google_storage_bucket.tfe) == 1 ? google_storage_bucket.tfe[0].id : null
#   description = "Name of TFE gcs bucket."
# }

# output "google_sql_database_instance_id" {
#   value       = length(google_sql_database_instance.tfe) == 1 ? google_sql_database_instance.tfe[0].id : null
#   description = "ID of Cloud SQL DB instance."
# }

# output "gcp_db_instance_ip" {
#   value       = length(google_sql_database_instance.tfe) == 1 ? google_sql_database_instance.tfe[0].private_ip_address : null
#   description = "Cloud SQL DB instance IP."
# }

# output "user_data_template" {
#   value     = var.verbose_template != null ? google_compute_instance_template.tfe.metadata_startup_script : null
#   sensitive = true
# }

# output "tfe_retrieve_iact" {
#   value       = var.tfe_iact_subnets != "" ? "https://${var.tfe_fqdn}/admin/retrieve-iact" : null
#   description = "Terraform-Enterprise URL to retrieve initial user token based on `tfe_fqdn` input, and `tfe_iact_subnets` is set"
# }

# output "tfe_initial_user_url" {
#   value       = var.tfe_iact_subnets != "" ? "https://${var.tfe_fqdn}/admin/account/new?token=<IACT_TOKEN>" : null
#   description = "Terraform-Enterprise URL create initial admin user based on the `tfe_fqdn` input, and `tfe_iact_subnets` is set"
# }
