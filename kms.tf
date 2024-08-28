# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#-----------------------------------------------------------------------------------
# GCS Encryption
#-----------------------------------------------------------------------------------
data "google_kms_key_ring" "gcs_bucket" {
  count = var.gcs_bucket_keyring_name == null ? 0 : 1

  name     = var.gcs_bucket_keyring_name
  location = var.gcs_bucket_location
}

data "google_kms_crypto_key" "gcs_bucket" {
  count = var.gcs_bucket_key_name == null ? 0 : 1

  name     = var.gcs_bucket_key_name
  key_ring = data.google_kms_key_ring.gcs_bucket[0].id
}

#-----------------------------------------------------------------------------------
# SQL Encryption
#-----------------------------------------------------------------------------------
data "google_kms_key_ring" "postgres" {
  count = var.postgres_keyring_name == null ? 0 : 1

  name     = var.postgres_keyring_name
  location = data.google_client_config.default.region
}

data "google_kms_crypto_key" "postgres" {
  count = var.postgres_key_name == null ? 0 : 1

  name     = var.postgres_key_name
  key_ring = data.google_kms_key_ring.postgres[0].id
}
