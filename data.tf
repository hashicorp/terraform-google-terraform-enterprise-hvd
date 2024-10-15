# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Google client config
#------------------------------------------------------------------------------
data "google_client_config" "current" {}

#------------------------------------------------------------------------------
# Google project
#------------------------------------------------------------------------------
data "google_project" "current" {}

#------------------------------------------------------------------------------
# Availability zones
#------------------------------------------------------------------------------
data "google_compute_zones" "up" {
  project = var.vpc_network_project_id != null ? var.vpc_network_project_id : var.project_id
  status  = "UP"
}

#------------------------------------------------------------------------------
# Networking
#------------------------------------------------------------------------------
data "google_compute_network" "vpc" {
  name    = var.vpc_network_name
  project = var.vpc_network_project_id != null ? var.vpc_network_project_id : var.project_id
}

data "google_compute_subnetwork" "vm_subnet" {
  name = var.vm_subnet_name
}

data "google_compute_subnetwork" "lb_subnet" {
  count = var.lb_subnet_name != null ? 1 : 0
  
  name = var.lb_subnet_name
}