# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Cloud Memorystore for Redis
#------------------------------------------------------------------------------
resource "google_redis_instance" "tfe" {
  count = var.tfe_operational_mode == "active-active" ? 1 : 0
  
  name                    = "${var.friendly_name_prefix}-tfe-redis"
  display_name            = "${var.friendly_name_prefix}-tfe-redis"
  tier                    = var.redis_tier
  redis_version           = var.redis_version
  memory_size_gb          = var.redis_memory_size_gb
  auth_enabled            = var.redis_auth_enabled
  transit_encryption_mode = var.redis_transit_encryption_mode
  authorized_network      = data.google_compute_network.vpc.self_link
  connect_mode            = var.redis_connect_mode
  labels                  = var.common_labels
}

#------------------------------------------------------------------------------
# KMS customer managed encryption key (CMEK)
#------------------------------------------------------------------------------
data "google_kms_key_ring" "redis" {
  count = var.redis_kms_keyring_name != null ? 1 : 0

  name     = var.redis_kms_keyring_name
  location = data.google_client_config.current.region
}

data "google_kms_crypto_key" "redis" {
  count = var.redis_kms_cmek_name != null ? 1 : 0

  name     = var.redis_kms_cmek_name
  key_ring = data.google_kms_key_ring.redis[0].id
}