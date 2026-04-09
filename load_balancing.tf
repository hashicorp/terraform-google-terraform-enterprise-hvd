# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Common
#------------------------------------------------------------------------------
locals {
  lb_name_suffix = var.lb_is_internal ? "internal" : "external"

  is_calver_tag            = can(regex("^v[0-9]{6}-[0-9]+$", var.tfe_image_tag))
  normalized_tfe_image_tag = trimprefix(var.tfe_image_tag, "v")
  semver_parts             = can(regex("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$", local.normalized_tfe_image_tag)) ? split(".", local.normalized_tfe_image_tag) : []
  semver_major             = length(local.semver_parts) > 0 ? tonumber(local.semver_parts[0]) : 0
  semver_minor             = length(local.semver_parts) > 1 ? tonumber(local.semver_parts[1]) : 0
  semver_patch             = length(local.semver_parts) > 2 ? tonumber(local.semver_parts[2]) : 0

  tfe_readiness_endpoint_path = !local.is_calver_tag && length(local.semver_parts) > 0 && (
    local.semver_major > 1 ||
    (local.semver_major == 1 && (local.semver_minor > 2 || (local.semver_minor == 2 && local.semver_patch >= 1)))
  ) ? "/api/v1/health/readiness" : "/_health_check"
}

#-----------------------------------------------------------------------------------
# Frontend
#-----------------------------------------------------------------------------------
resource "google_compute_address" "tfe_frontend_lb" {
  name         = "${var.friendly_name_prefix}-tfe-frontend-lb-ip"
  description  = "Static IP to associate with TFE load balancer forwarding rule (front end)."
  address_type = var.lb_is_internal ? "INTERNAL" : "EXTERNAL"
  network_tier = var.lb_is_internal ? null : "PREMIUM"
  subnetwork   = var.lb_is_internal ? data.google_compute_subnetwork.lb_subnet[0].self_link : null
  address      = var.lb_is_internal ? var.lb_static_ip_address : null
}

resource "google_compute_forwarding_rule" "tfe_frontend_lb" {
  name                  = "${var.friendly_name_prefix}-tfe-frontend-lb-${local.lb_name_suffix}"
  backend_service       = google_compute_region_backend_service.tfe_backend_lb.id
  ip_protocol           = "TCP"
  load_balancing_scheme = var.lb_is_internal ? "INTERNAL" : "EXTERNAL"
  ports                 = [443]
  network               = var.lb_is_internal ? data.google_compute_network.vpc.self_link : null
  subnetwork            = var.lb_is_internal ? data.google_compute_subnetwork.lb_subnet[0].self_link : null
  ip_address            = google_compute_address.tfe_frontend_lb.address
}

resource "google_compute_forwarding_rule" "tfe_admin_console_lb" {
  count = var.tfe_admin_console_disabled ? 0 : 1

  name                  = "${var.friendly_name_prefix}-tfe-admin-console-lb-${local.lb_name_suffix}"
  backend_service       = google_compute_region_backend_service.tfe_backend_lb.id
  ip_protocol           = "TCP"
  load_balancing_scheme = var.lb_is_internal ? "INTERNAL" : "EXTERNAL"
  ports                 = [var.tfe_admin_https_port]
  network               = var.lb_is_internal ? data.google_compute_network.vpc.self_link : null
  subnetwork            = var.lb_is_internal ? data.google_compute_subnetwork.lb_subnet[0].self_link : null
  ip_address            = google_compute_address.tfe_frontend_lb.address
}

#-----------------------------------------------------------------------------------
# Backend
#-----------------------------------------------------------------------------------
resource "google_compute_region_backend_service" "tfe_backend_lb" {
  name                  = "${var.friendly_name_prefix}-tfe-backend-lb-${local.lb_name_suffix}"
  protocol              = "TCP"
  load_balancing_scheme = var.lb_is_internal ? "INTERNAL" : "EXTERNAL"

  backend {
    description    = "TFE ${local.lb_name_suffix} regional backend service."
    group          = google_compute_region_instance_group_manager.tfe.instance_group
    balancing_mode = "CONNECTION"
    failover       = false
  }

  health_checks = [google_compute_region_health_check.tfe_backend_lb.self_link]
}

resource "google_compute_region_health_check" "tfe_backend_lb" {
  name               = "${var.friendly_name_prefix}-tfe-backend-svc-health-check"
  check_interval_sec = 5
  timeout_sec        = 5

  https_health_check {
    port         = 443
    request_path = local.tfe_readiness_endpoint_path
  }
}
