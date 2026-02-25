# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Log forwarding (Fluent Bit) config
#------------------------------------------------------------------------------
locals {
  fluent_bit_stackdriver_args = {
    region               = var.tfe_log_forwarding_enabled && var.log_fwd_destination_type == "stackdriver" ? data.google_client_config.current.region : null
    friendly_name_prefix = var.tfe_log_forwarding_enabled && var.log_fwd_destination_type == "stackdriver" ? var.friendly_name_prefix : null
  }
  fluent_bit_stackdriver_config = var.tfe_log_forwarding_enabled && var.log_fwd_destination_type == "stackdriver" ? (templatefile("${path.module}/templates/fluent-bit-stackdriver.conf.tpl", local.fluent_bit_stackdriver_args)) : ""

  fluent_bit_custom_config = var.log_fwd_destination_type == "custom" ? var.custom_fluent_bit_config : ""

  fluent_bit_rendered_config = join("", [local.fluent_bit_stackdriver_config, local.fluent_bit_custom_config])
}

#-----------------------------------------------------------------------------------
# Metadata startup script
#-----------------------------------------------------------------------------------
locals {
  tfe_startup_script_tpl = var.custom_tfe_startup_script_template != null ? "${path.cwd}/templates/${var.custom_tfe_startup_script_template}" : "${path.module}/templates/tfe_startup_script.sh.tpl"
  redis_port             = var.redis_transit_encryption_mode == "SERVER_AUTHENTICATION" ? "6378" : "6379"

  startup_script_args = {
    # Bootstrap
    tfe_license_secret_id             = var.tfe_license_secret_id
    tfe_encryption_password_secret_id = var.tfe_encryption_password_secret_id
    tfe_tls_cert_secret_id            = var.tfe_tls_cert_secret_id
    tfe_tls_privkey_secret_id         = var.tfe_tls_privkey_secret_id
    tfe_tls_ca_bundle_secret_id       = var.tfe_tls_ca_bundle_secret_id
    tfe_image_repository_url          = var.tfe_image_repository_url
    tfe_image_repository_username     = var.tfe_image_repository_username
    tfe_image_repository_password     = var.tfe_image_repository_password != null ? var.tfe_image_repository_password : ""
    tfe_image_name                    = var.tfe_image_name
    tfe_image_tag                     = var.tfe_image_tag
    container_runtime                 = var.container_runtime
    docker_version                    = var.docker_version

    # https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/configuration
    # TFE application settings
    tfe_hostname                  = var.tfe_fqdn
    tfe_operational_mode          = var.tfe_operational_mode
    tfe_capacity_concurrency      = var.tfe_capacity_concurrency
    tfe_capacity_cpu              = var.tfe_capacity_cpu
    tfe_capacity_memory           = var.tfe_capacity_memory
    tfe_license_reporting_opt_out = var.tfe_license_reporting_opt_out
    tfe_usage_reporting_opt_out   = var.tfe_usage_reporting_opt_out
    tfe_run_pipeline_driver       = "docker"
    tfe_run_pipeline_image        = var.tfe_run_pipeline_image != null ? var.tfe_run_pipeline_image : ""
    tfe_backup_restore_token      = ""
    tfe_node_id                   = ""
    tfe_http_port                 = var.tfe_http_port
    tfe_https_port                = var.tfe_https_port

    # Database settings
    tfe_database_host       = "${google_sql_database_instance.tfe.private_ip_address}:5432"
    tfe_database_name       = var.tfe_database_name
    tfe_database_user       = var.tfe_database_user
    tfe_database_password   = data.google_secret_manager_secret_version.tfe_database_password.secret_data
    tfe_database_parameters = var.tfe_database_parameters

    # Object storage settings
    tfe_object_storage_type               = "google"
    tfe_object_storage_google_bucket      = google_storage_bucket.tfe.name
    tfe_object_storage_google_credentials = google_service_account_key.tfe.private_key
    tfe_object_storage_google_project     = var.project_id

    # Redis settings
    tfe_redis_host     = var.tfe_operational_mode == "active-active" ? "${google_redis_instance.tfe[0].host}:${local.redis_port}" : ""
    tfe_redis_use_auth = var.redis_auth_enabled
    tfe_redis_user     = var.tfe_operational_mode == "active-active" && var.redis_auth_enabled ? "default" : ""
    tfe_redis_password = var.tfe_operational_mode == "active-active" && var.redis_auth_enabled ? google_redis_instance.tfe[0].auth_string : ""
    tfe_redis_use_tls  = var.redis_transit_encryption_mode == "SERVER_AUTHENTICATION" ? true : false

    # TLS settings
    tfe_tls_cert_file      = "/etc/ssl/private/terraform-enterprise/cert.pem"
    tfe_tls_key_file       = "/etc/ssl/private/terraform-enterprise/key.pem"
    tfe_tls_ca_bundle_file = "/etc/ssl/private/terraform-enterprise/bundle.pem"
    tfe_tls_enforce        = var.tfe_tls_enforce
    tfe_tls_ciphers        = "" # Leave blank to use the default ciphers
    tfe_tls_version        = "" # Leave blank to use both TLS v1.2 and TLS v1.3

    # Observability settings
    tfe_log_forwarding_enabled = var.tfe_log_forwarding_enabled
    tfe_metrics_enable         = var.tfe_metrics_enable
    tfe_metrics_http_port      = var.tfe_metrics_http_port
    tfe_metrics_https_port     = var.tfe_metrics_https_port
    fluent_bit_rendered_config = local.fluent_bit_rendered_config

    # Docker driver settings
    tfe_run_pipeline_docker_network = var.tfe_run_pipeline_docker_network != null ? var.tfe_run_pipeline_docker_network : ""
    tfe_hairpin_addressing          = var.tfe_hairpin_addressing
    #tfe_run_pipeline_docker_extra_hosts = "" // computed inside of tfe_user_data script if `tfe_hairpin_addressing` is `true` because VM private IP is needed

    # Network settings
    tfe_iact_subnets         = var.tfe_iact_subnets != null ? var.tfe_iact_subnets : ""
    tfe_iact_time_limit      = var.tfe_iact_time_limit != null ? var.tfe_iact_time_limit : ""
    tfe_iact_trusted_proxies = var.tfe_iact_trusted_proxies != null ? var.tfe_iact_trusted_proxies : ""

    # Vault settings
    tfe_vault_use_external  = false
    tfe_vault_disable_mlock = var.tfe_vault_disable_mlock
  }
}

#------------------------------------------------------------------------------
# GCE VM image
#------------------------------------------------------------------------------
data "google_compute_image" "tfe" {
  name    = var.gce_image_name
  project = var.gce_image_project
}

#------------------------------------------------------------------------------
# Instance template
#------------------------------------------------------------------------------
resource "google_compute_instance_template" "tfe" {
  name_prefix    = "${var.friendly_name_prefix}-tfe-template-"
  machine_type   = var.gce_machine_type
  can_ip_forward = false

  disk {
    source_image = data.google_compute_image.tfe.self_link
    auto_delete  = true
    boot         = true
    disk_size_gb = var.gce_disk_size_gb
    disk_type    = "pd-ssd"
    mode         = "READ_WRITE"
    type         = "PERSISTENT"
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.vm_subnet.self_link
  }

  metadata_startup_script = templatefile("${local.tfe_startup_script_tpl}", local.startup_script_args)

  metadata = {
    ssh-keys = var.gce_ssh_public_key
  }

  service_account {
    scopes = ["cloud-platform"]
    email  = google_service_account.tfe.email
  }

  labels = var.common_labels
  tags   = ["tfe-vm"]

  lifecycle {
    create_before_destroy = true
  }
}

#------------------------------------------------------------------------------
# Managed instance group (MIG)
#------------------------------------------------------------------------------
resource "google_compute_region_instance_group_manager" "tfe" {
  name                      = "${var.friendly_name_prefix}-tfe-ig-mgr"
  base_instance_name        = "${var.friendly_name_prefix}-tfe-vm"
  distribution_policy_zones = data.google_compute_zones.up.names
  target_size               = var.mig_instance_count

  version {
    instance_template = google_compute_instance_template.tfe.self_link
  }

  named_port {
    name = "tfe-app"
    port = 443
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.tfe_auto_healing.self_link
    initial_delay_sec = var.mig_initial_delay_sec
  }

  update_policy {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    instance_redistribution_type   = "PROACTIVE"
    max_surge_fixed                = length(data.google_compute_zones.up.names)
    max_unavailable_fixed          = length(data.google_compute_zones.up.names)
    replacement_method             = "SUBSTITUTE"
  }
}

resource "google_compute_health_check" "tfe_auto_healing" {
  name                = "${var.friendly_name_prefix}-tfe-autohealing-health-check"
  check_interval_sec  = 30
  healthy_threshold   = 2
  unhealthy_threshold = 5
  timeout_sec         = 5

  https_health_check {
    port         = 443
    request_path = "/_health_check"
  }
}

#------------------------------------------------------------------------------
# Firewalls
#------------------------------------------------------------------------------
resource "google_compute_firewall" "vm_allow_ingress_ssh_from_cidr" {
  count = var.cidr_allow_ingress_vm_ssh != null ? 1 : 0

  name        = "${var.friendly_name_prefix}-tfe-allow-ssh-from-cidr"
  description = "Allow TCP/22 ingress to TFE GCE VM instances from specified CIDR ranges."
  network     = data.google_compute_network.vpc.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  source_ranges = var.cidr_allow_ingress_vm_ssh
  target_tags   = ["tfe-vm"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vm_allow_ingress_ssh_from_iap" {
  count = var.allow_ingress_vm_ssh_from_iap ? 1 : 0

  name        = "${var.friendly_name_prefix}-tfe-allow-ssh-from-iap"
  description = "Allow TCP/22 ingress to TFE GCE VM instances from IAP."
  network     = data.google_compute_network.vpc.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["tfe-vm"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vm_allow_tfe_443" {
  count = var.cidr_allow_ingress_tfe_443 != null ? 1 : 0

  name        = "${var.friendly_name_prefix}-tfe-allow-443"
  description = "Allow TCP/443 (HTTPS) ingress to TFE GCE VM instances from specified CIDR ranges."
  network     = data.google_compute_network.vpc.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [443]
  }

  source_ranges = var.cidr_allow_ingress_tfe_443
  target_tags   = ["tfe-vm"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

locals {
  // https://cloud.google.com/load-balancing/docs/health-check-concepts
  health_check_probe_cidrs = var.lb_is_internal ? ["130.211.0.0/22", "35.191.0.0/16"] : ["35.191.0.0/16", "209.85.152.0/22", "209.85.204.0/22"]
}

resource "google_compute_firewall" "vm_allow_lb_health_checks_443" {
  name        = "${var.friendly_name_prefix}-tfe-allow-lb-health-checks-443"
  description = "Allow TCP/443 (HTTPS) inbound to TFE GCE VM instances from GCP load balancer health probe source CIDR blocks."
  network     = data.google_compute_network.vpc.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [443]
  }

  source_ranges = local.health_check_probe_cidrs
  target_tags   = ["tfe-vm"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vm_tfe_self_allow" {
  count = var.tfe_operational_mode == "active-active" ? 1 : 0

  name        = "${var.friendly_name_prefix}-tfe-self-allow"
  description = "Allow TFE GCE VM instances to communicate with each other over TCP/8201 (Vault cluster) when TFE operational mode is active-active."
  network     = data.google_compute_network.vpc.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [8201]
  }

  source_tags = ["tfe-vm"]
  target_tags = ["tfe-vm"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vm_allow_tfe_metrics_from_cidr" {
  count = var.tfe_metrics_enable && var.cidr_allow_ingress_tfe_metrics != null ? 1 : 0

  name        = "${var.friendly_name_prefix}-tfe-allow-metrics"
  description = "Allow TCP/9090 (HTTP) and 9091 (HTTPS) or specified ports ingress to TFE metrics endpoints on TFE GCE VM instances from specified CIDR ranges."
  network     = data.google_compute_network.vpc.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [var.tfe_metrics_http_port, var.tfe_metrics_https_port]
  }

  source_ranges = var.cidr_allow_ingress_tfe_metrics
  target_tags   = ["tfe-vm"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}