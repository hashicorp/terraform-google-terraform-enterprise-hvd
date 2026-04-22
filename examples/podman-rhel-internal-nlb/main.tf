# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.6"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

module "tfe" {
  source = "../.."

  # --- Common --- #
  project_id           = var.project_id
  region               = var.region
  friendly_name_prefix = var.friendly_name_prefix
  common_labels        = var.common_labels

  # --- Bootstrap --- #
  tfe_license_secret_id                 = var.tfe_license_secret_id
  tfe_encryption_password_secret_id     = var.tfe_encryption_password_secret_id
  tfe_tls_cert_secret_id                = var.tfe_tls_cert_secret_id
  tfe_tls_privkey_secret_id             = var.tfe_tls_privkey_secret_id
  tfe_tls_ca_bundle_secret_id           = var.tfe_tls_ca_bundle_secret_id
  tfe_tls_cert_secret_id_secondary      = var.tfe_tls_cert_secret_id_secondary
  tfe_tls_privkey_secret_id_secondary   = var.tfe_tls_privkey_secret_id_secondary
  tfe_tls_ca_bundle_secret_id_secondary = var.tfe_tls_ca_bundle_secret_id_secondary

  # --- TFE config settings --- #
  tfe_fqdn                     = var.tfe_fqdn
  tfe_hostname_secondary       = var.tfe_hostname_secondary
  tfe_oidc_hostname_choice     = var.tfe_oidc_hostname_choice
  tfe_vcs_hostname_choice      = var.tfe_vcs_hostname_choice
  tfe_run_task_hostname_choice = var.tfe_run_task_hostname_choice
  tfe_image_tag                = var.tfe_image_tag
  tfe_admin_https_port         = var.tfe_admin_https_port
  tfe_admin_console_disabled   = var.tfe_admin_console_disabled

  # --- Networking --- #
  vpc_network_name                     = var.vpc_network_name
  lb_is_internal                       = var.lb_is_internal
  lb_subnet_name                       = var.lb_subnet_name
  vm_subnet_name                       = var.vm_subnet_name
  cidr_allow_ingress_tfe_443           = var.cidr_allow_ingress_tfe_443
  cidr_allow_ingress_tfe_admin_console = var.cidr_allow_ingress_tfe_admin_console
  create_secondary_tfe_lb              = var.create_secondary_tfe_lb
  cidr_allow_ingress_tfe_secondary_443 = var.cidr_allow_ingress_tfe_secondary_443
  allow_ingress_vm_ssh_from_iap        = var.allow_ingress_vm_ssh_from_iap

  # --- DNS (optional) --- #
  create_tfe_cloud_dns_record           = var.create_tfe_cloud_dns_record
  cloud_dns_managed_zone_name           = var.cloud_dns_managed_zone_name
  create_tfe_secondary_cloud_dns_record = var.create_tfe_secondary_cloud_dns_record
  secondary_cloud_dns_managed_zone_name = var.secondary_cloud_dns_managed_zone_name

  # --- Compute --- #
  mig_instance_count = var.mig_instance_count
  gce_image_name     = var.gce_image_name
  gce_image_project  = var.gce_image_project
  container_runtime  = var.container_runtime

  # --- Database --- #
  tfe_database_password_secret_id = var.tfe_database_password_secret_id

  # --- Log forwarding (optional) --- #
  tfe_log_forwarding_enabled = var.tfe_log_forwarding_enabled
  log_fwd_destination_type   = var.log_fwd_destination_type
}
