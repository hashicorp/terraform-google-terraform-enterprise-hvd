#-----------------------------------------------------------------------------------
# Storage Bucket
#-----------------------------------------------------------------------------------
resource "random_id" "gcs_bucket_suffix" {
  count       = contains(["active-active", "external"], var.tfe_operational_mode) ? 1 : 0
  byte_length = 4
}

resource "google_storage_bucket" "tfe" {
  count                       = contains(["active-active", "external"], var.tfe_operational_mode) ? 1 : 0
  name                        = "${var.friendly_name_prefix}-tfe-bucket-${random_id.gcs_bucket_suffix[0].hex}"
  storage_class               = "MULTI_REGIONAL"
  location                    = upper(var.gcs_bucket_location)
  uniform_bucket_level_access = true

  dynamic "encryption" {
    for_each = var.gcs_bucket_key_name != null ? ["encryption"] : []
    content {
      default_kms_key_name = data.google_kms_crypto_key.gcs_bucket[0].id
    }
  }

  versioning {
    enabled = true
  }

  force_destroy = var.gcs_force_destroy
  labels        = var.common_labels

  depends_on = [google_kms_crypto_key_iam_member.gcs_account]
}
