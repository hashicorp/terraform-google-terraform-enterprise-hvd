# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0




locals {
  #------------------------------------------------------------------------------
  # Log Forwarding
  #------------------------------------------------------------------------------
  fluent_bit_stackdriver_args = {
    region               = var.tfe_log_forwarding_enabled == true && var.log_fwd_destination_type == "stackdriver" ? data.google_client_config.default.region : null
    friendly_name_prefix = var.tfe_log_forwarding_enabled == true && var.log_fwd_destination_type == "stackdriver" ? var.friendly_name_prefix : null
  }
  fluent_bit_stackdriver_config = var.tfe_log_forwarding_enabled == true && var.log_fwd_destination_type == "stackdriver" ? (templatefile("${path.module}/templates/fluent-bit-stackdriver.conf.tpl", local.fluent_bit_stackdriver_args)) : ""

  fluent_bit_custom_config = var.log_fwd_destination_type == "custom" ? var.custom_fluent_bit_config : ""

  fluent_bit_rendered_config = join("", [local.fluent_bit_stackdriver_config, local.fluent_bit_custom_config])
}

#-----------------------------------------------------------------------------------
# User-Data
#-----------------------------------------------------------------------------------
locals {
  tfe_user_data_template = fileexists("${path.module}/templates/${var.tfe_user_data_template}") ? "${path.module}/templates/${var.tfe_user_data_template}" : "${path.cwd}/templates/${var.tfe_user_data_template}"
  user_data_args = {
    region                            = var.region
    tfe_license_secret_id             = var.tfe_license_secret_id
    tfe_tls_cert_secret_id            = var.tfe_tls_cert_secret_id
    tfe_tls_privkey_secret_id         = var.tfe_tls_privkey_secret_id
    tfe_tls_ca_bundle_secret_id       = var.tfe_tls_ca_bundle_secret_id
    tfe_encryption_password_secret_id = var.tfe_encryption_password_secret_id
    tfe_image_repository_url          = var.tfe_image_repository_url
    tfe_image_repository_username     = var.tfe_image_repository_username
    tfe_image_repository_password     = var.tfe_image_repository_password
    tfe_image_name                    = var.tfe_image_name
    tfe_image_tag                     = var.tfe_image_tag
    docker_version                    = var.docker_version
    tfe_mounted_disk_path             = var.tfe_mounted_disk_path

    # https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/configuration
    # TFE application settings
    tfe_hostname                  = var.tfe_fqdn
    tfe_operational_mode          = var.tfe_operational_mode
    tfe_capacity_concurrency      = var.tfe_capacity_concurrency
    tfe_capacity_cpu              = var.tfe_capacity_cpu
    tfe_capacity_memory           = var.tfe_capacity_memory
    tfe_license_reporting_opt_out = var.tfe_license_reporting_opt_out
    tfe_run_pipeline_driver       = "docker"
    tfe_run_pipeline_image        = var.tfe_run_pipeline_image == null ? "" : var.tfe_run_pipeline_image
    tfe_backup_restore_token      = ""
    tfe_node_id                   = ""
    tfe_http_port                 = 80
    tfe_https_port                = 443
    # Network bootstrap settings
    tfe_iact_subnets         = var.tfe_iact_subnets
    tfe_iact_time_limit      = var.tfe_iact_time_limit
    tfe_iact_trusted_proxies = var.tfe_iact_trusted_proxies

    # Database settings
    tfe_database_host       = length(google_sql_database_instance.tfe) == 1 ? google_sql_database_instance.tfe[0].private_ip_address : null
    tfe_database_name       = length(google_sql_database.tfe) == 1 ? google_sql_database.tfe[0].name : null
    tfe_database_user       = length(google_sql_user.tfe) == 1 ? google_sql_user.tfe[0].name : null
    tfe_database_password   = length(data.google_secret_manager_secret_version.tfe_database_password_secret_id) == 1 ? nonsensitive(data.google_secret_manager_secret_version.tfe_database_password_secret_id[0].secret_data) : null
    tfe_database_parameters = var.postgres_extra_params

    # Object storage settings
    tfe_object_storage_type               = "google"
    tfe_object_storage_google_bucket      = length(google_storage_bucket.tfe) == 1 ? google_storage_bucket.tfe[0].name : null
    tfe_object_storage_google_credentials = google_service_account_key.tfe.private_key
    tfe_object_storage_google_project     = data.google_client_config.default.project

    # Redis settings

    tfe_redis_host     = contains(["active-active"], var.tfe_operational_mode) ? google_redis_instance.tfe[0].host : ""
    tfe_redis_password = contains(["active-active"], var.tfe_operational_mode) ? google_redis_instance.tfe[0].auth_string : ""
    #tfe_redis_use_auth = false
    tfe_redis_use_auth = contains(["active-active"], var.tfe_operational_mode) ? true : ""
    tfe_redis_use_tls  = false
    #tfe_redis_use_tls = contains(["active-active"], var.tfe_operational_mode)? != null ? true : false

    # TLS settings
    tfe_tls_cert_file      = "/etc/ssl/private/terraform-enterprise/cert.pem"
    tfe_tls_key_file       = "/etc/ssl/private/terraform-enterprise/key.pem"
    tfe_tls_ca_bundle_file = "/etc/ssl/private/terraform-enterprise/bundle.pem"
    tfe_tls_enforce        = var.tfe_tls_enforce
    tfe_tls_ciphers        = ""
    tfe_tls_version        = ""

    # Observability settings
    tfe_log_forwarding_enabled = var.tfe_log_forwarding_enabled
    tfe_metrics_enable         = var.tfe_metrics_enable
    tfe_metrics_http_port      = var.tfe_metrics_http_port
    tfe_metrics_https_port     = var.tfe_metrics_https_port
    fluent_bit_rendered_config = local.fluent_bit_rendered_config

    # Vault settings
    tfe_vault_use_external  = false
    tfe_vault_disable_mlock = var.tfe_vault_disable_mlock

    # Docker driver settings
    tfe_run_pipeline_docker_extra_hosts = "" # computed inside of tfe_user_data script if `tfe_hairpin_addressing` is `true` because EC2 private IP is used
    tfe_run_pipeline_docker_network     = var.tfe_run_pipeline_docker_network == null ? "" : var.tfe_run_pipeline_docker_network
    tfe_disk_cache_path                 = "/var/cache/tfe-task-worker"
    tfe_disk_cache_volume_name          = "tfe_terraform-enterprise-cache"
    tfe_hairpin_addressing              = var.load_balancing_scheme == true ? true : var.tfe_hairpin_addressing

    # Network bootstrap settings
    tfe_iact_subnets         = var.tfe_iact_subnets
    tfe_iact_time_limit      = var.tfe_iact_time_limit
    tfe_iact_trusted_proxies = var.tfe_iact_trusted_proxies
  }
}

# data "cloudinit_config" "tfe_cloudinit" {
#   gzip          = true
#   base64_encode = true

#   part {
#     filename     = "tfe_user_data.sh"
#     content_type = "text/x-shellscript"
#     content      = templatefile("local.tfe_user_data_template", local.user_data_args)
#   }
# }

#-----------------------------------------------------------------------------------
# Instance Template
#-----------------------------------------------------------------------------------

resource "google_compute_instance_template" "tfe" {
  name_prefix    = "${var.friendly_name_prefix}-tfe-template-"
  machine_type   = var.machine_type
  can_ip_forward = true

  disk {
    source_image = data.google_compute_image.tfe.self_link
    auto_delete  = true
    boot         = true
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-ssd"
    mode         = "READ_WRITE"
    type         = "PERSISTENT"
  }

  network_interface {
    subnetwork = var.subnet
  }

  # metadata = {
  #   user-data          = data.cloudinit_config.tfe_cloudinit.rendered
  #   user-data-encoding = "base64"
  # }
  metadata_startup_script = templatefile("${local.tfe_user_data_template}", local.user_data_args)

  service_account {
    scopes = ["cloud-platform"]
    email  = google_service_account.tfe.email
  }

  labels = var.common_labels
  tags   = ["tfe-backend"]

  lifecycle {
    create_before_destroy = true
  }
}

#-----------------------------------------------------------------------------------
# Instance Group
#-----------------------------------------------------------------------------------
resource "google_compute_region_instance_group_manager" "tfe" {
  name                      = "${var.friendly_name_prefix}-tfe-ig-mgr"
  base_instance_name        = "${var.friendly_name_prefix}-tfe-vm"
  distribution_policy_zones = data.google_compute_zones.up.names
  target_size               = var.instance_count

  version {
    instance_template = google_compute_instance_template.tfe.self_link
  }

  named_port {
    name = "tfe-app"
    port = 443
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.tfe_auto_healing.self_link
    initial_delay_sec = var.initial_delay_sec
  }

  update_policy {
    minimal_action = "REPLACE"
    type           = "PROACTIVE"

    max_surge_fixed       = 0 //length(data.google_compute_zones.up.names)
    max_unavailable_fixed = length(data.google_compute_zones.up.names)
  }
}

resource "google_compute_health_check" "tfe_auto_healing" {
  name                = "${var.friendly_name_prefix}-tfe-autohealing-health-check"
  check_interval_sec  = 30
  healthy_threshold   = 2
  unhealthy_threshold = 7
  timeout_sec         = 10

  https_health_check {
    port         = 443
    request_path = "/_health_check"
  }
}

#-----------------------------------------------------------------------------------
# Firewall
#-----------------------------------------------------------------------------------
resource "google_compute_firewall" "allow_ssh" {
  name        = "${var.friendly_name_prefix}-${data.google_compute_network.vpc.name}-tfe-firewall-ssh-allow"
  description = "Allow SSH ingress to TFE instances from specified CIDR ranges."
  network     = data.google_compute_network.vpc.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [22]
  }
  source_ranges = var.cidr_ingress_ssh_allow
  target_tags   = ["tfe-backend"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_https" {
  name        = "${var.friendly_name_prefix}-tfe-firewall-https-allow"
  description = "Allow HTTPS traffic ingress to TFE instances in ${data.google_compute_network.vpc.name} from specified CIDR ranges."
  network     = data.google_compute_network.vpc.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [443]
  }

  source_ranges = var.cidr_ingress_https_allow
  target_tags   = ["tfe-backend"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
resource "google_compute_firewall" "allow_iap" {
  count       = var.enable_iap == true ? 1 : 0
  name        = "${var.friendly_name_prefix}-tfe-firewall-iap-allow"
  description = "Allow https://cloud.google.com/iap/docs/using-tcp-forwarding#console traffic"
  network     = data.google_compute_network.vpc.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [3389, 22]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["tfe-backend"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
resource "google_compute_firewall" "health_checks" {
  name        = "${var.friendly_name_prefix}-tfe-health-checks-allow"
  description = "Allow GCP Health Check CIDRs to talk to TFE in ${data.google_compute_network.vpc.name}."
  network     = data.google_compute_network.vpc.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [443]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["tfe-backend"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "tfe_self" {
  name        = "${var.friendly_name_prefix}-tfe-self-allow"
  description = "Allow TFE instance(s) in ${data.google_compute_network.vpc.name} to communicate with each other."
  network     = data.google_compute_network.vpc.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [443, 8201]
  }

  source_tags = ["tfe-backend"]
  target_tags = ["tfe-backend"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_prometheus" {
  count = var.tfe_metrics_enable == true ? 1 : 0

  name        = "${var.friendly_name_prefix}-tfe-firewall-prometheus-allow"
  description = "Allow prometheus traffic ingress to TFE instances in ${data.google_compute_network.vpc.name} from specified tag."
  network     = data.google_compute_network.vpc.self_link
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [9090, 9091]
  }

  source_tags = ["tfe-monitoring"]
  target_tags = ["tfe-backend"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
