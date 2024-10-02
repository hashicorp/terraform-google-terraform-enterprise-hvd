# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.5"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.5"
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
  tfe_license_secret_id             = var.tfe_license_secret_id
  tfe_encryption_password_secret_id = var.tfe_encryption_password_secret_id
  tfe_tls_cert_secret_id            = var.tfe_tls_cert_secret_id
  tfe_tls_privkey_secret_id         = var.tfe_tls_privkey_secret_id
  tfe_tls_ca_bundle_secret_id       = var.tfe_tls_ca_bundle_secret_id

  # --- TFE config settings --- #
  tfe_fqdn      = var.tfe_fqdn
  tfe_image_tag = var.tfe_image_tag

  # --- Networking --- #
  vpc_network_name              = var.vpc_network_name
  vm_subnet_name                = var.vm_subnet_name
  lb_is_internal                = var.lb_is_internal 
  cidr_allow_ingress_tfe_443    = var.cidr_allow_ingress_tfe_443
  allow_ingress_vm_ssh_from_iap = var.allow_ingress_vm_ssh_from_iap

  # --- DNS (optional) --- #
  create_tfe_cloud_dns_record = var.create_tfe_cloud_dns_record
  cloud_dns_managed_zone_name = var.cloud_dns_managed_zone_name

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
