# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Google Secret Manager - TFE database password lookup
#------------------------------------------------------------------------------
data "google_secret_manager_secret_version" "tfe_database_password" {
  secret = var.tfe_database_password_secret_id
}

data "google_secret_manager_secret_version" "tfe_explorer_database_password" {
  count = var.tfe_explorer_database_password_secret_id != null ? 1 : 0

  secret = var.tfe_explorer_database_password_secret_id
}

#------------------------------------------------------------------------------
# Cloud SQL for PostgreSQL
#------------------------------------------------------------------------------
resource "random_id" "postgres_instance_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "tfe" {
  name                = "${var.friendly_name_prefix}-tfe-postgres-${random_id.postgres_instance_suffix.hex}"
  database_version    = var.postgres_version
  encryption_key_name = var.postgres_kms_cmek_name != null ? data.google_kms_crypto_key.postgres_cmek[0].id : null
  deletion_protection = var.postgres_deletetion_protection

  settings {
    availability_type = var.postgres_availability_type
    tier              = var.postgres_machine_type
    disk_type         = "PD_SSD"
    disk_size         = var.postgres_disk_size
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.vpc.self_link
      ssl_mode        = var.postgres_ssl_mode
    }

    dynamic "database_flags" {
      for_each = var.tfe_explorer_enabled && var.tfe_explorer_database_auth_use_gcp_iam && local.tfe_explorer_database_uses_tfe_database ? [1] : []

      content {
        name  = "cloudsql.iam_authentication"
        value = "on"
      }
    }

    backup_configuration {
      enabled    = true
      start_time = var.postgres_backup_start_time
    }

    maintenance_window {
      day          = var.postgres_maintenance_window.day
      hour         = var.postgres_maintenance_window.hour
      update_track = var.postgres_maintenance_window.update_track
    }

    insights_config {
      query_insights_enabled  = var.postgres_insights_config.query_insights_enabled
      query_plans_per_minute  = var.postgres_insights_config.query_plans_per_minute
      query_string_length     = var.postgres_insights_config.query_string_length
      record_application_tags = var.postgres_insights_config.record_application_tags
      record_client_address   = var.postgres_insights_config.record_client_address
    }

    user_labels = var.common_labels
  }

  depends_on = [google_kms_crypto_key_iam_member.postgres_cmek]
}

resource "google_sql_database_instance" "tfe_explorer" {
  count = local.tfe_explorer_database_is_module_managed ? 1 : 0

  name                = "${var.friendly_name_prefix}-tfe-explorer-postgres-${random_id.postgres_instance_suffix.hex}"
  database_version    = var.postgres_version
  encryption_key_name = var.postgres_kms_cmek_name != null ? data.google_kms_crypto_key.postgres_cmek[0].id : null
  deletion_protection = var.postgres_deletetion_protection

  settings {
    availability_type = var.postgres_availability_type
    tier              = var.postgres_machine_type
    disk_type         = "PD_SSD"
    disk_size         = var.postgres_disk_size
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.vpc.self_link
      ssl_mode        = var.postgres_ssl_mode
    }

    dynamic "database_flags" {
      for_each = var.tfe_explorer_database_auth_use_gcp_iam ? [1] : []

      content {
        name  = "cloudsql.iam_authentication"
        value = "on"
      }
    }

    backup_configuration {
      enabled    = true
      start_time = var.postgres_backup_start_time
    }

    maintenance_window {
      day          = var.postgres_maintenance_window.day
      hour         = var.postgres_maintenance_window.hour
      update_track = var.postgres_maintenance_window.update_track
    }

    insights_config {
      query_insights_enabled  = var.postgres_insights_config.query_insights_enabled
      query_plans_per_minute  = var.postgres_insights_config.query_plans_per_minute
      query_string_length     = var.postgres_insights_config.query_string_length
      record_application_tags = var.postgres_insights_config.record_application_tags
      record_client_address   = var.postgres_insights_config.record_client_address
    }

    user_labels = var.common_labels
  }

  depends_on = [google_kms_crypto_key_iam_member.postgres_cmek]
}

resource "google_sql_database" "tfe" {
  name     = var.tfe_database_name
  instance = google_sql_database_instance.tfe.name
}

resource "google_sql_user" "tfe" {
  name     = var.tfe_database_user
  instance = google_sql_database_instance.tfe.name
  password = data.google_secret_manager_secret_version.tfe_database_password.secret_data
}

resource "google_sql_database" "tfe_explorer" {
  count = local.tfe_explorer_database_is_module_managed ? 1 : 0

  name     = local.tfe_explorer_managed_database_name
  instance = google_sql_database_instance.tfe_explorer[0].name
}

resource "google_sql_user" "tfe_explorer" {
  count = local.tfe_explorer_database_is_module_managed && !var.tfe_explorer_database_auth_use_gcp_iam ? 1 : 0

  name     = local.tfe_explorer_managed_database_user
  instance = google_sql_database_instance.tfe_explorer[0].name
  password = var.tfe_explorer_database_password_secret_id != null ? data.google_secret_manager_secret_version.tfe_explorer_database_password[0].secret_data : data.google_secret_manager_secret_version.tfe_database_password.secret_data
}

resource "google_sql_user" "tfe_explorer_iam" {
  count = var.tfe_explorer_enabled && var.tfe_explorer_database_auth_use_gcp_iam && local.tfe_explorer_database_is_module_managed ? 1 : 0

  name     = local.tfe_explorer_iam_database_user
  instance = google_sql_database_instance.tfe_explorer[0].name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

resource "google_sql_user" "tfe_primary_explorer_iam" {
  count = var.tfe_explorer_enabled && var.tfe_explorer_database_auth_use_gcp_iam && local.tfe_explorer_database_uses_tfe_database ? 1 : 0

  name     = local.tfe_explorer_iam_database_user
  instance = google_sql_database_instance.tfe.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

#------------------------------------------------------------------------------
# KMS customer managed encryption key (CMEK)
#------------------------------------------------------------------------------
data "google_kms_key_ring" "postgres_cmek" {
  count = var.postgres_kms_keyring_name != null ? 1 : 0

  name     = var.postgres_kms_keyring_name
  location = data.google_client_config.current.region
}

data "google_kms_crypto_key" "postgres_cmek" {
  count = var.postgres_kms_cmek_name != null ? 1 : 0

  name     = var.postgres_kms_cmek_name
  key_ring = data.google_kms_key_ring.postgres_cmek[0].id
}
