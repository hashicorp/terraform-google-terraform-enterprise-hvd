#-----------------------------------------------------------------------------------
# Service Account
#-----------------------------------------------------------------------------------
resource "google_service_account" "tfe" {
  account_id   = "${var.friendly_name_prefix}-tfe-svc-acct"
  display_name = "${var.friendly_name_prefix}-tfe-svc-acct"
  description  = "Service Account allowing TFE instance(s) to interact GCP resources and services."
}

resource "google_service_account_key" "tfe" {
  service_account_id = google_service_account.tfe.name
}

#-----------------------------------------------------------------------------------
# Cloud Storage Buckets
#-----------------------------------------------------------------------------------
resource "google_storage_bucket_iam_member" "tfe_bucket_object_admin" {
  count  = contains(["active-active", "external"], var.tfe_operational_mode) ? 1 : 0
  bucket = google_storage_bucket.tfe[0].id
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.tfe.email}"
}

resource "google_storage_bucket_iam_member" "tfe_bucket_reader" {
  count  = contains(["active-active", "external"], var.tfe_operational_mode) ? 1 : 0
  bucket = google_storage_bucket.tfe[0].id
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.tfe.email}"
}

#-----------------------------------------------------------------------------------
# Cloud Storage Bucket Encryption
#-----------------------------------------------------------------------------------
resource "google_kms_crypto_key_iam_member" "gcs_bucket" {
  count = var.gcs_bucket_key_name == null ? 0 : 1

  crypto_key_id = data.google_kms_crypto_key.gcs_bucket[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.tfe.email}"
}

resource "google_kms_crypto_key_iam_member" "gcs_account" {
  count = var.gcs_bucket_key_name == null ? 0 : 1

  crypto_key_id = data.google_kms_crypto_key.gcs_bucket[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  member = "serviceAccount:${data.google_storage_project_service_account.project.email_address}"
}

#-----------------------------------------------------------------------------------
# Cloud SQL Encryption
#-----------------------------------------------------------------------------------
resource "google_kms_crypto_key_iam_member" "postgres" {
  count = var.postgres_keyring_name == null ? 0 : 1

  crypto_key_id = data.google_kms_crypto_key.postgres[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.project.email_address}"
}

resource "google_kms_crypto_key_iam_member" "postgres_account" {
  count = var.postgres_keyring_name == null ? 0 : 1

  crypto_key_id = data.google_kms_crypto_key.postgres[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.tfe.email}"
}

resource "google_kms_crypto_key_iam_member" "postgres_project" {
  count = var.postgres_keyring_name == null ? 0 : 1

  crypto_key_id = data.google_kms_crypto_key.postgres[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql[0].email}"
}

#-----------------------------------------------------------------------------------
# Secret Manager
#-----------------------------------------------------------------------------------
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

resource "google_secret_manager_secret_iam_member" "ca_bundle" {
  count = var.tfe_tls_ca_bundle_secret_id != "" ? 1 : 0

  secret_id = var.tfe_tls_ca_bundle_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.tfe.email}"
}

resource "google_secret_manager_secret_iam_member" "tfe_encryption_password" {
  count     = var.tfe_encryption_password_secret_id != "" ? 1 : 0
  secret_id = var.tfe_encryption_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.tfe.email}"
}
resource "google_secret_manager_secret_iam_member" "tfe_license" {
  count = var.tfe_license_secret_id != "" ? 1 : 0

  secret_id = var.tfe_license_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.tfe.email}"
}
resource "google_project_service_identity" "gcp_sa_cloud_sql" {
  count    = var.tfe_database_password_secret_id != null || var.postgres_keyring_name != null ? 1 : 0
  provider = google-beta
  service  = "sqladmin.googleapis.com"
}

#-----------------------------------------------------------------------------------
# Stackdriver
#-----------------------------------------------------------------------------------
resource "google_project_iam_member" "stackdriver" {
  count = var.tfe_log_forwarding_enabled == true && var.log_fwd_destination_type == "stackdriver" ? 1 : 0

  project = data.google_client_config.default.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.tfe.email}"
}
