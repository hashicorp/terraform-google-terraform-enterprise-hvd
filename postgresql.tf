# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#-----------------------------------------------------------------------------------
# Cloud SQL for PostgreSQL
#-----------------------------------------------------------------------------------
resource "random_id" "postgres_suffix" {
  count       = var.tfe_database_password_secret_id != null ? 1 : 0
  byte_length = 4
}

resource "google_compute_global_address" "postgres_private_ip" {
  count         = var.tfe_database_password_secret_id != null ? 1 : 0
  name          = "${var.friendly_name_prefix}-tfe-postgres-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.google_compute_network.vpc.self_link
}

resource "google_service_networking_connection" "postgres_endpoint" {
  count                   = var.tfe_database_password_secret_id != null ? 1 : 0
  network                 = data.google_compute_network.vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.postgres_private_ip[0].name]
}

resource "google_sql_database_instance" "tfe" {
  count    = var.tfe_database_password_secret_id != null ? 1 : 0
  provider = google-beta

  name                = "${var.friendly_name_prefix}-tfe-${random_id.postgres_suffix[0].hex}"
  database_version    = var.postgres_version
  encryption_key_name = var.postgres_key_name == null ? null : data.google_kms_crypto_key.postgres[0].id
  deletion_protection = false

  settings {
    availability_type = var.postgres_availability_type
    tier              = var.postgres_machine_type
    disk_type         = "PD_SSD"
    disk_size         = var.postgres_disk_size
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.vpc.self_link
      #require_ssl     = true
    }

    backup_configuration {
      enabled    = true
      start_time = var.postgres_backup_start_time
    }

    user_labels = var.common_labels
  }

  depends_on = [google_service_networking_connection.postgres_endpoint[0], google_kms_crypto_key_iam_member.postgres_account]
}

resource "google_sql_database" "tfe" {
  count    = var.tfe_database_password_secret_id != null ? 1 : 0
  name     = "tfe"
  instance = google_sql_database_instance.tfe[0].name
}

resource "google_sql_user" "tfe" {
  count    = var.tfe_database_password_secret_id != null ? 1 : 0
  name     = "tfe"
  instance = google_sql_database_instance.tfe[0].name
  password = nonsensitive(data.google_secret_manager_secret_version.tfe_database_password_secret_id[0].secret_data)
}
