data "google_dns_managed_zone" "tfe" {
  count = var.create_cloud_dns_record == true ? 1 : 0

  name = var.cloud_dns_managed_zone
}

resource "google_dns_record_set" "tfe" {
  count = var.create_cloud_dns_record == true ? 1 : 0

  managed_zone = data.google_dns_managed_zone.tfe[0].name
  name         = "${var.tfe_fqdn}."
  type         = "A"
  ttl          = 60
  rrdatas      = [google_compute_address.tfe_frontend_lb.address]
}