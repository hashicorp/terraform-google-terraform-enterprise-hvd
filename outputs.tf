# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# TFE URLs
#------------------------------------------------------------------------------
output "tfe_url" {
  value       = "https://${var.tfe_fqdn}"
  description = "URL of TFE application based on `tfe_fqdn` input value."
}

output "tfe_retrieve_iact_url" {
  value       = var.tfe_iact_subnets != null ? "https://${var.tfe_fqdn}/admin/retrieve-iact" : null
  description = "URL to retrieve TFE initial admin creation token."
}

output "tfe_create_initial_admin_user_url" {
  value       = "https://${var.tfe_fqdn}/admin/account/new?token=<IACT_TOKEN>"
  description = "URL to create TFE initial admin user."
}

#------------------------------------------------------------------------------
# Load balancer
#------------------------------------------------------------------------------
output "tfe_lb_ip_address" {
  value       = google_compute_address.tfe_frontend_lb.address
  description = "IP Address of TFE front end load balancer (forwarding rule)."
}

output "tfe_load_balancing_scheme" {
  value       = google_compute_forwarding_rule.tfe_frontend_lb.load_balancing_scheme
  description = "Load balancing scheme of TFE front end load balancer (forwarding rule)."
}

#------------------------------------------------------------------------------
# Database
#------------------------------------------------------------------------------
output "tfe_database_instance_id" {
  value       = google_sql_database_instance.tfe.id
  description = "ID of TFE Cloud SQL for PostgreSQL database instance."
}

output "tfe_database_host" {
  value       = "${google_sql_database_instance.tfe.private_ip_address}:5432"
  description = "Private IP address and port of TFE Cloud SQL for PostgreSQL database instance."
}

output "tfe_database_name" {
  value       = var.tfe_database_name
  description = "Name of TFE database."
}

output "tfe_database_user" {
  value       = var.tfe_database_user
  description = "Username of TFE database."
}

output "tfe_database_password" {
  value       = data.google_secret_manager_secret_version.tfe_database_password.secret_data
  description = "Password of TFE database user."
  sensitive   = true
}

#------------------------------------------------------------------------------
# Object storage
#------------------------------------------------------------------------------
output "tfe_object_storage_google_bucket" {
  value       = google_storage_bucket.tfe.id
  description = "Name of TFE GCS bucket."
}

output "tfe_gcs_bucket_location" {
  value       = google_storage_bucket.tfe.location
  description = "Location of TFE GCS bucket."
}

#------------------------------------------------------------------------------
# Redis
#------------------------------------------------------------------------------
output "tfe_redis_host" {
  value       = var.tfe_operational_mode == "active-active" ? local.startup_script_args["tfe_redis_host"] : null
  description = "Hostname/IP address (and port if non-default) of TFE Redis instance."
}

output "tfe_redis_use_auth" {
  value       = var.tfe_operational_mode == "active-active" ? var.redis_auth_enabled : null
  description = "Whether TFE should use authentication to connect to Redis instance."
}

output "tfe_redis_user" {
  value       = var.tfe_operational_mode == "active-active" ? local.startup_script_args["tfe_redis_user"] : null
  description = "Username of TFE Redis instance."
}

output "tfe_redis_password" {
  value       = var.tfe_operational_mode == "active-active" ? local.startup_script_args["tfe_redis_password"] : null
  description = "Password of TFE Redis instance."
  sensitive   = true
}

output "tfe_redis_use_tls" {
  value       = var.tfe_operational_mode == "active-active" ? local.startup_script_args["tfe_redis_use_tls"] : null
  description = "Whether TFE should use TLS to connect to Redis instance."
}

