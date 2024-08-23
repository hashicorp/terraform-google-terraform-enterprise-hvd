#-----------------------------------------------------------------------------------
# Networking
#-----------------------------------------------------------------------------------
data "google_compute_subnetwork" "subnet" {
  name = var.subnet
}

#-----------------------------------------------------------------------------------
# Frontend
#-----------------------------------------------------------------------------------
resource "google_compute_address" "tfe_frontend_lb" {
  name         = "${var.friendly_name_prefix}-tfe-frontend-lb-ip"
  description  = "Static IP to associate with TFE Forwarding Rule (frontend of TCP load balancer)."
  address_type = upper(var.load_balancing_scheme)
  network_tier = "PREMIUM"
  subnetwork   = var.load_balancing_scheme == "internal" ? data.google_compute_subnetwork.subnet.self_link : null
}

resource "google_compute_forwarding_rule" "tfe_frontend_lb" {
  name                  = "${var.friendly_name_prefix}-tfe-tcp-${var.load_balancing_scheme}-lb"
  backend_service       = google_compute_region_backend_service.tfe_backend_lb.id
  ip_protocol           = "TCP"
  load_balancing_scheme = upper(var.load_balancing_scheme)
  ports                 = [443]
  network               = var.load_balancing_scheme == "internal" ? data.google_compute_subnetwork.subnet.self_link : null
  subnetwork            = var.load_balancing_scheme == "internal" ? data.google_compute_subnetwork.subnet.self_link : null
  ip_address            = google_compute_address.tfe_frontend_lb.address
}

#-----------------------------------------------------------------------------------
# Backend
#-----------------------------------------------------------------------------------
resource "google_compute_region_backend_service" "tfe_backend_lb" {
  name                  = "${var.friendly_name_prefix}-tfe-backend-${var.load_balancing_scheme}-lb"
  protocol              = "TCP"
  load_balancing_scheme = upper(var.load_balancing_scheme)
  timeout_sec           = 60

  backend {
    description = "TFE Backend Regional Internal TCP/UDP Load Balancer"
    group       = google_compute_region_instance_group_manager.tfe.instance_group
  }

  health_checks = [google_compute_region_health_check.tfe_backend_lb.self_link]
}

resource "google_compute_region_health_check" "tfe_backend_lb" {
  name               = "${var.friendly_name_prefix}-tfe-backend-svc-health-check"
  check_interval_sec = 5
  timeout_sec        = 5

  https_health_check {
    port         = 443
    request_path = "/_health_check"
  }
}
