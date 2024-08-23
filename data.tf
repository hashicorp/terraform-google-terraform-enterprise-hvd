#------------------------------------------------------------------------------
# Client Config
#------------------------------------------------------------------------------
data "google_client_config" "default" {}

#------------------------------------------------------------------------------
# VPC Network
#------------------------------------------------------------------------------
data "google_compute_network" "vpc" {
  name    = var.network
  project = var.network_project_id != null ? var.network_project_id : var.project_id
}

#------------------------------------------------------------------------------
# Availability Zones
#------------------------------------------------------------------------------
data "google_compute_zones" "up" {
  project = var.network_project_id != null ? var.network_project_id : var.project_id
  status  = "UP"
}

#------------------------------------------------------------------------------
# Secret Manager
#------------------------------------------------------------------------------
data "google_secret_manager_secret_version" "tfe_database_password_secret_id" {
  count  = var.tfe_database_password_secret_id != null ? 1 : 0
  secret = var.tfe_database_password_secret_id
}
#-----------------------------------------------------------------------------------
# Image
#-----------------------------------------------------------------------------------
data "google_compute_image" "tfe" {
  name    = var.image_name
  project = var.image_project
}
#-----------------------------------------------------------------------------------
# service account
#-----------------------------------------------------------------------------------

data "google_storage_project_service_account" "project" {}
