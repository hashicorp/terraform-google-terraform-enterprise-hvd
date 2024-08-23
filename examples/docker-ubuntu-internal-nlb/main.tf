module "tfe_fdo_default" {
  source = "../.."
  # --- Common --- #
  project_id           = var.project_id
  region               = var.region
  friendly_name_prefix = var.friendly_name_prefix
  common_labels        = var.common_labels
  # tfe install
  tfe_fqdn              = var.tfe_fqdn
  tfe_license_secret_id = var.tfe_license_secret_id
  # secrets

  tfe_encryption_password_secret_id = var.tfe_encryption_password_secret_id
  tfe_tls_cert_secret_id            = var.tfe_tls_cert_secret_id
  tfe_tls_privkey_secret_id         = var.tfe_tls_privkey_secret_id
  tfe_tls_ca_bundle_secret_id       = var.tfe_tls_ca_bundle_secret_id
  tfe_database_password_secret_id   = var.tfe_database_password_secret_id
  tfe_iact_subnets                  = var.tfe_iact_subnets
  # network
  network                 = var.network
  subnet                  = var.subnet
  tfe_operational_mode    = var.tfe_operational_mode
  create_cloud_dns_record = var.create_cloud_dns_record
  cloud_dns_managed_zone  = var.cloud_dns_managed_zone
  instance_count          = var.instance_count
}
