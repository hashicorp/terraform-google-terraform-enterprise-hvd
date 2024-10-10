# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# TFE URLs
#------------------------------------------------------------------------------
output "tfe_url" {
  value       = "https://${var.tfe_fqdn}"
  description = "URL of TFE application based on `tfe_fqdn` input."
}

output "tfe_iact_url" {
  value       = "https://${var.tfe_fqdn}/admin/account/new?token=<IACT_TOKEN>"
  description = "TFE URL create initial admin user based on the."
}

output "tfe_retrieve_iact" {
  value       = "https://${var.tfe_fqdn}/admin/retrieve-iact"
  description = "TFE URL to retrieve initial user token based on `tfe_fqdn` input, and `tfe_iact_subnets` is set"
}

output "lb_ip_address" {
  value       = google_compute_address.tfe_frontend_lb.address
  description = "IP Address of TFE front end load balancer (forwarding rule)."
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
