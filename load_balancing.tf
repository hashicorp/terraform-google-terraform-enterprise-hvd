# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Common
#------------------------------------------------------------------------------
locals {
  lb_name_suffix = var.lb_is_internal ? "internal" : "external"
}

#-----------------------------------------------------------------------------------
# Frontend
#-----------------------------------------------------------------------------------
resource "google_compute_address" "tfe_frontend_lb" {
  name         = "${var.friendly_name_prefix}-tfe-frontend-lb-ip"
  description  = "Static IP to associate with TFE load balancer forwarding rule (front end)."
  address_type = var.lb_is_internal ? "INTERNAL" : "EXTERNAL"
  network_tier = var.lb_is_internal ? null : "PREMIUM"
  subnetwork   = var.lb_is_internal ? data.google_compute_subnetwork.vm_subnet.self_link : null
  address      = var.lb_is_internal ? var.lb_static_ip_address : null 
}

resource "google_compute_forwarding_rule" "tfe_frontend_lb" {
  name                  = "${var.friendly_name_prefix}-tfe-frontend-lb-${local.lb_name_suffix}"
  backend_service       = google_compute_region_backend_service.tfe_backend_lb.id
  ip_protocol           = "TCP"
  load_balancing_scheme = var.lb_is_internal ? "INTERNAL" : "EXTERNAL"
  ports                 = [443]
  network               = var.lb_is_internal ? data.google_compute_network.vpc.self_link : null
  subnetwork            = var.lb_is_internal ? data.google_compute_subnetwork.vm_subnet.self_link : null
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
    request_path = "/_health_check"
  }
}
