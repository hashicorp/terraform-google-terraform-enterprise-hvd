# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Cloud DNS managed zone lookup
#------------------------------------------------------------------------------
data "google_dns_managed_zone" "tfe" {
  count = var.create_tfe_cloud_dns_record && var.cloud_dns_managed_zone_name != null ? 1 : 0

  name = var.cloud_dns_managed_zone_name
}

#------------------------------------------------------------------------------
# Cloud DNS record set
#------------------------------------------------------------------------------
locals {
  tfe_dns_record_name = !endswith(var.tfe_fqdn, ".") ? "${var.tfe_fqdn}." : var.tfe_fqdn
}

resource "google_dns_record_set" "tfe" {
  count = var.create_tfe_cloud_dns_record && var.cloud_dns_managed_zone_name != null ? 1 : 0

  managed_zone = data.google_dns_managed_zone.tfe[0].name
  name         = local.tfe_dns_record_name
  type         = "A"
  ttl          = 60
  rrdatas      = [google_compute_address.tfe_frontend_lb.address]
}