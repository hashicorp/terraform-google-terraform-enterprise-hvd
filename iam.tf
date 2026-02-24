# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# TFE service account
#------------------------------------------------------------------------------
resource "google_service_account" "tfe" {
  account_id   = "${var.friendly_name_prefix}-tfe-svc-acct"
  display_name = "${var.friendly_name_prefix}-tfe-svc-acct"
  description  = "Custom service account to be associated with TFE GCE VM instances."
}

resource "google_service_account_key" "tfe" {
  service_account_id = google_service_account.tfe.name
}

resource "google_storage_bucket_iam_member" "tfe_bucket_object_admin" {
  bucket = google_storage_bucket.tfe.id
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.tfe.email}"
}

resource "google_storage_bucket_iam_member" "tfe_bucket_reader" {
  bucket = google_storage_bucket.tfe.id
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.tfe.email}"
}

resource "google_secret_manager_secret_iam_member" "tfe_license" {
  count = var.tfe_license_secret_id != "" ? 1 : 0

  secret_id = var.tfe_license_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.tfe.email}"
}

resource "google_secret_manager_secret_iam_member" "tfe_encryption_password" {
  count = var.tfe_encryption_password_secret_id != "" ? 1 : 0

  secret_id = var.tfe_encryption_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.tfe.email}"
}

resource "google_secret_manager_secret_iam_member" "tfe_cert" {
  count = var.tfe_tls_cert_secret_id != "" ? 1 : 0

  secret_id = var.tfe_tls_cert_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.tfe.email}"
}

resource "google_secret_manager_secret_iam_member" "tfe_privkey" {
  count = var.tfe_tls_privkey_secret_id != "" ? 1 : 0

  secret_id = var.tfe_tls_privkey_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.tfe.email}"
}

resource "google_secret_manager_secret_iam_member" "tfe_ca_bundle" {
  count = var.tfe_tls_ca_bundle_secret_id != "" ? 1 : 0

  secret_id = var.tfe_tls_ca_bundle_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.tfe.email}"
}

resource "google_project_iam_member" "tfe_logging_stackdriver" {
  count = var.tfe_log_forwarding_enabled && var.log_fwd_destination_type == "stackdriver" ? 1 : 0

  project = data.google_client_config.current.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.tfe.email}"
}

#------------------------------------------------------------------------------
# Cloud SQL - KMS
#------------------------------------------------------------------------------
// There is no Google-managed service account (service agent) for Cloud SQL,
// so one must be created to allow the Cloud SQL instance to use the CMEK.
// https://cloud.google.com/sql/docs/postgres/configure-cmek
resource "google_project_service_identity" "gcp_project_cloud_sql_sa" {
  count    = var.postgres_kms_keyring_name != null ? 1 : 0
  provider = google-beta

  service = "sqladmin.googleapis.com"
}

resource "google_kms_crypto_key_iam_member" "postgres_cmek" {
  count = var.postgres_kms_keyring_name != null ? 1 : 0

  crypto_key_id = data.google_kms_crypto_key.postgres_cmek[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.gcp_project_cloud_sql_sa[0].email}"
}

#------------------------------------------------------------------------------
# GCS bucket - KMS
#------------------------------------------------------------------------------
data "google_storage_project_service_account" "gcp_project_gcs_sa" {
  count = var.gcs_kms_cmek_name != null ? 1 : 0
}

resource "google_kms_crypto_key_iam_member" "gcp_project_gcs_sa_cmek" {
  count = var.gcs_kms_cmek_name != null ? 1 : 0

  crypto_key_id = data.google_kms_crypto_key.gcs_cmek[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcp_project_gcs_sa[0].email_address}"
}

#------------------------------------------------------------------------------
# Cloud Memorystore (Redis) - KMS
#------------------------------------------------------------------------------
locals {
  redis_service_account_email = "service-${data.google_project.current.number}@cloud-redis.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "gcp_project_redis_sa_cmek" {
  count = var.redis_kms_cmek_name != null ? 1 : 0

  crypto_key_id = data.google_kms_crypto_key.redis_cmek[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${local.redis_service_account_email}"
}