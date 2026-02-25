# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Common
#------------------------------------------------------------------------------
variable "project_id" {
  type        = string
  description = "ID of GCP project to deploy TFE in."
}

variable "region" {
  type        = string
  description = "GCP region (location) to deploy TFE in."
}

variable "friendly_name_prefix" {
  type        = string
  description = "Friendly name prefix used for uniquely naming all GCP resources for this deployment. Most commonly set to either an environment (e.g. 'sandbox', 'prod'), a team name, or a project name."

  validation {
    condition     = !strcontains(var.friendly_name_prefix, "tfe")
    error_message = "Value must not contain the substring 'tfe' to avoid redundancy in resource naming."
  }
}

variable "common_labels" {
  type        = map(string)
  description = "Map of common labels to apply to all GCP resources."
  default     = {}
}

variable "is_secondary_region" {
  type        = bool
  description = "Boolean indicating whether this TFE deployment is in your primary region or secondary (disaster recovery) region."
  default     = false
}

#------------------------------------------------------------------------------
# Bootstrap
#------------------------------------------------------------------------------
variable "tfe_license_secret_id" {
  type        = string
  description = "Name of Google Secret Manager secret for TFE license file."
}

variable "tfe_tls_cert_secret_id" {
  type        = string
  description = "Name of Google Secret Manager secret for TFE TLS certificate in PEM format. Secret must be stored as a base64-encoded string."
}

variable "tfe_tls_privkey_secret_id" {
  type        = string
  description = "Name of Google Secret Manager secret for TFE TLS private key in PEM format. Secret must be stored as a base64-encoded string."
}

variable "tfe_tls_ca_bundle_secret_id" {
  type        = string
  description = "Name of Google Secret Manager secret for private/custom TLS Certificate Authority (CA) bundle in PEM format. Secret must be stored as a base64-encoded string."
}

variable "tfe_encryption_password_secret_id" {
  type        = string
  description = "Name of Google Secret Manager secret for TFE encryption password."
}

variable "tfe_image_repository_url" {
  type        = string
  description = "URL of container registry where the TFE container image is hosted. Only set this away from the default if you are hosting the TFE container image in your own custom registry."
  default     = "images.releases.hashicorp.com"
}

variable "tfe_image_name" {
  type        = string
  description = "Name of the TFE container image. Only set this away from the default if you are hosting the TFE container image in your own custom registry."
  default     = "hashicorp/terraform-enterprise"
}

variable "tfe_image_tag" {
  type        = string
  description = "Tag (release) for the TFE container image. This represents which version (release) of TFE to deploy."
  default     = "v202409-3"
}

variable "tfe_image_repository_username" {
  type        = string
  description = "Username for container registry where TFE container image is hosted."
  default     = "terraform"
}

variable "tfe_image_repository_password" {
  type        = string
  description = "Pasword for container registry where TFE container image is hosted. Leave as `null` if using the default TFE registry, as the default password is your TFE license file."
  default     = null

  validation {
    condition     = var.tfe_image_repository_url != "images.releases.hashicorp.com" ? var.tfe_image_repository_password != null : true
    error_message = "Value must be set when `tfe_image_repository_url` is not the default TFE registry (`images.releases.hashicorp.com`)."
  }
}

#------------------------------------------------------------------------------
# TFE configuration settings
#------------------------------------------------------------------------------
variable "tfe_fqdn" {
  type        = string
  description = "Fully qualified domain name (FQDN) of TFE instance. This name should resolve to the TFE load balancer IP address and will be what users/clients use to access TFE."
}

variable "tfe_operational_mode" {
  type        = string
  description = "[Operational mode](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/operation-modes) for TFE. Valid values are `active-active` or `external`."
  default     = "active-active"

  validation {
    condition     = var.tfe_operational_mode == "active-active" || var.tfe_operational_mode == "external"
    error_message = "Value must be `active-active` or `external`."
  }
}

variable "tfe_http_port" {
  type        = number
  description = "HTTP port for TFE application containers to listen on."
  default     = 8080

  validation {
    condition     = var.container_runtime == "podman" ? var.tfe_http_port != 80 : true
    error_message = "Value must not be `80` when `container_runtime` is `podman` to avoid conflicts."
  }
}

variable "tfe_https_port" {
  type        = number
  description = "HTTPS port for TFE application containers to listen on."
  default     = 8443

  validation {
    condition     = var.container_runtime == "podman" ? var.tfe_https_port != 443 : true
    error_message = "Value must not be `80` when `container_runtime` is `podman` to avoid conflicts."
  }
}

variable "tfe_capacity_concurrency" {
  type        = number
  description = "Maximum number of concurrent Terraform runs to allow on a TFE node."
  default     = 10
}

variable "tfe_capacity_cpu" {
  type        = number
  description = "Maxium number of CPU cores that a Terraform run is allowed to consume on a TFE node. Defaults to `0` which is no limit."
  default     = 0
}

variable "tfe_capacity_memory" {
  type        = number
  description = "Maximum amount of memory (in MiB) that a Terraform run is allowed to consume on a TFE node."
  default     = 2048
}

variable "tfe_license_reporting_opt_out" {
  type        = bool
  description = "Boolean to opt out of TFE license reporting."
  default     = false
}

variable "tfe_usage_reporting_opt_out" {
  type        = bool
  description = "Boolean to opt out of TFE usage reporting."
  default     = false
}

variable "tfe_run_pipeline_image" {
  type        = string
  description = "Name of container image used to execute Terraform runs on a TFE node. Leave as `null` to use the default agent that ships with TFE."
  default     = null
}

variable "tfe_metrics_enable" {
  type        = bool
  description = "Boolean to enable TFE metrics collection endpoints."
  default     = false
}

variable "tfe_metrics_http_port" {
  type        = number
  description = "HTTP port for TFE metrics collection endpoint to listen on."
  default     = 9090
}

variable "tfe_metrics_https_port" {
  type        = number
  description = "HTTPS port for TFE metrics collection endpoint to listen on."
  default     = 9091
}

variable "tfe_tls_enforce" {
  type        = bool
  description = "Boolean to enforce TLS, Strict-Transport-Security headers, and secure cookies within TFE."
  default     = false
}

variable "tfe_vault_disable_mlock" {
  type        = bool
  description = "Boolean to disable mlock for internal (embedded) Vault within TFE."
  default     = false
}

variable "tfe_hairpin_addressing" {
  type        = bool
  description = "Boolean to enable hairpin addressing within TFE container networking for loopback prevention with a layer 4 internal load balancer."
  default     = true
}

variable "tfe_run_pipeline_docker_network" {
  type        = string
  description = "Name of Docker network where the containers that execute Terraform runs (agents) will be created. The network must already exist, it will not be created automatically. Leave as `null` to use the default network created during the TFE installation."
  default     = null
}

variable "tfe_iact_subnets" {
  type        = string
  description = "Comma-separated list of subnets in CIDR notation that are allowed to retrieve the TFE initial admin creation token via the API or web browser."
  default     = null
}

variable "tfe_iact_time_limit" {
  type        = number
  description = "Number of minutes that the TFE initial admin creation token can be retrieved via the API after the application starts."
  default     = 60
}

variable "tfe_iact_trusted_proxies" {
  type        = string
  description = "Comma-separated list of proxy IP addresses that are allowed to retrieve the TFE initial admin creation token via the API or web browser."
  default     = null
}

#------------------------------------------------------------------------------
# Networking
#------------------------------------------------------------------------------
variable "vpc_network_name" {
  type        = string
  description = "Name of VPC network to deploy TFE in."
}

variable "vpc_network_project_id" {
  type        = string
  description = "ID of GCP project where the existing VPC network resides, if it is different than the `project_id` where TFE will be deployed."
  default     = null
}

variable "lb_subnet_name" {
  type        = string
  description = "Name of VPC subnet to deploy TFE load balancer in. This can be the same subnet as the VM subnet if you do not wish to provide a separate subnet for the load balancer. Only applicable when `lb_is_internal` is `true`. Must be `null` when `lb_is_internal` is `false`."
  default     = null

  validation {
    condition     = !var.lb_is_internal ? var.lb_subnet_name == null : true
    error_message = "Value must be `null` when `lb_is_internal` is `false`."
  }
}

variable "vm_subnet_name" {
  type        = string
  description = "Name of VPC subnet to deploy TFE GCE VM instances in."
}

variable "lb_is_internal" {
  type        = bool
  description = "Boolean to create an internal GCP load balancer for TFE."
  default     = true
}

variable "lb_static_ip_address" {
  type        = string
  description = "Static IP address to assign to TFE load balancer forwarding rule (front end) when `lb_is_internal` is `true`. Must be a valid IP address within `vm_subnet_name`. If not set, an available IP address will automatically be selected."
  default     = null

  validation {
    condition     = !var.lb_is_internal ? var.lb_static_ip_address == null : true
    error_message = "Value must be `null` when `lb_is_internal` is `false`. This setting is for internal load balancers only."
  }
}

variable "cidr_allow_ingress_tfe_443" {
  type        = list(string)
  description = "List of CIDR ranges to allow TCP/443 (HTTPS) inbound to TFE load balancer."
  default     = null
}

variable "cidr_allow_ingress_vm_ssh" {
  type        = list(string)
  description = "List of CIDR ranges to allow TCP/22 (SSH) inbound to TFE GCE instances."
  default     = null
}

variable "allow_ingress_vm_ssh_from_iap" {
  type        = bool
  description = "Boolean to create firewall rule to allow TCP/22 (SSH) inbound to TFE GCE instances from Google Cloud IAP CIDR block."
  default     = true
}

variable "cidr_allow_ingress_tfe_metrics" {
  type        = list(string)
  description = "List of CIDR ranges to allow TCP/9090 (HTTP) and TCP/9091 (HTTPS) inbound to TFE metrics collection endpoint."
  default     = null
}

#------------------------------------------------------------------------------
# DNS
#------------------------------------------------------------------------------
variable "create_tfe_cloud_dns_record" {
  type        = bool
  description = "Boolean to create Google Cloud DNS record for TFE using the value of `tfe_fqdn` as the record name, resolving to the load balancer IP. `cloud_dns_managed_zone_name` is required when `true`."
  default     = false
}

variable "cloud_dns_managed_zone_name" {
  type        = string
  description = "Name of Google Cloud DNS managed zone to create TFE DNS record in. Required when `create_tfe_cloud_dns_record` is `true`."
  default     = null

  validation {
    condition     = var.create_tfe_cloud_dns_record ? var.cloud_dns_managed_zone_name != null : true
    error_message = "Value must be set when `create_tfe_cloud_dns_record` is `true`."
  }
}

#------------------------------------------------------------------------------
# Compute
#------------------------------------------------------------------------------
variable "container_runtime" {
  type        = string
  description = "Container runtime to use for TFE deployment. Supported values are `docker` or `podman`."
  default     = "docker"

  validation {
    condition     = var.container_runtime == "docker" || var.container_runtime == "podman"
    error_message = "Valid values are `docker` or `podman`."
  }
}

variable "docker_version" {
  type        = string
  description = "Version of Docker to install on TFE GCE VM instances."
  default     = "26.1.4-1"
}

variable "gce_image_project" {
  type        = string
  description = "ID of project in which the TFE GCE VM image belongs."
  default     = "ubuntu-os-cloud"
}

variable "gce_image_name" {
  type        = string
  description = "VM image for TFE GCE instances."
  default     = "ubuntu-pro-2404-noble-amd64-v20241004"
}

variable "gce_machine_type" {
  type        = string
  description = "Machine type (size) of TFE GCE VM instances."
  default     = "n2-standard-4"
}

variable "gce_disk_size_gb" {
  type        = number
  description = "Size in gigabytes of root disk of TFE GCE VM instances."
  default     = 50
}

variable "gce_ssh_public_key" {
  type        = string
  description = "SSH public key to add to TFE GCE VM instances for SSH access. Generally not needed if using Google IAP for SSH."
  default     = null
}

variable "mig_instance_count" {
  type        = number
  description = "Desired number of TFE GCE instances to run in managed instance group. Must be `1` when `tfe_operational_mode` is `external`."
  default     = 1

  validation {
    condition     = var.tfe_operational_mode == "external" ? var.mig_instance_count == 1 : true
    error_message = "Value must be `1` when `tfe_operational_mode` is `external`."
  }
}

variable "mig_initial_delay_sec" {
  type        = number
  description = "Number of seconds for managed instance group to wait before applying autohealing policies to new GCE instances in managed instance group."
  default     = 900
}

variable "custom_tfe_startup_script_template" {
  type        = string
  description = "Name of custom TFE startup script template file. File must exist within a directory named `./templates` within your current working directory."
  default     = null

  validation {
    condition     = var.custom_tfe_startup_script_template != null ? fileexists("${path.cwd}/templates/${var.custom_tfe_startup_script_template}") : true
    error_message = "File not found. Ensure the file exists within a directory named `./templates` within your current working directory."
  }
}

#------------------------------------------------------------------------------
# Cloud SQL for PostgreSQL
#------------------------------------------------------------------------------
variable "tfe_database_password_secret_id" {
  type        = string
  description = "Name of PostgreSQL database password secret to retrieve from Google Secret Manager."
}

variable "tfe_database_name" {
  type        = string
  description = "Name of TFE PostgreSQL database to create."
  default     = "tfe"
}

variable "tfe_database_user" {
  type        = string
  description = "Name of TFE PostgreSQL database user to create."
  default     = "tfe"
}

variable "tfe_database_parameters" {
  type        = string
  description = "Additional parameters to pass into the TFE database settings for the PostgreSQL connection URI."
  default     = "sslmode=require"
}

variable "postgres_version" {
  type        = string
  description = "PostgreSQL version to use."
  default     = "POSTGRES_16"
}

variable "postgres_deletetion_protection" {
  type        = bool
  description = "Boolean to enable deletion protection for Cloud SQL for PostgreSQL instance."
  default     = false
}

variable "postgres_availability_type" {
  type        = string
  description = "Availability type of Cloud SQL for PostgreSQL instance."
  default     = "REGIONAL"
}

variable "postgres_machine_type" {
  type        = string
  description = "Machine size of Cloud SQL for PostgreSQL instance."
  default     = "db-custom-4-16384"
}

variable "postgres_disk_size" {
  type        = number
  description = "Size in GB of PostgreSQL disk."
  default     = 50
}

variable "postgres_backup_start_time" {
  type        = string
  description = "HH:MM time format indicating when daily automatic backups of Cloud SQL for PostgreSQL should run. Defaults to 12 AM (midnight) UTC."
  default     = "00:00"
}

variable "postgres_ssl_mode" {
  type        = string
  description = "Indicates whether to enforce TLS/SSL connections to the Cloud SQL for PostgreSQL instance."
  default     = "ENCRYPTED_ONLY"
}

variable "postgres_maintenance_window" {
  type = object({
    day          = number
    hour         = number
    update_track = string
  })
  description = "Optional maintenance window settings for the Cloud SQL for PostgreSQL instance."
  default = {
    day          = 7 # default to Sunday
    hour         = 0 # default to midnight
    update_track = "stable"
  }

  validation {
    condition     = var.postgres_maintenance_window.day >= 0 && var.postgres_maintenance_window.day <= 7
    error_message = "`day` must be an integer between 0 and 7 (inclusive)."
  }

  validation {
    condition     = var.postgres_maintenance_window.hour >= 0 && var.postgres_maintenance_window.hour <= 23
    error_message = "`hour` must be an integer between 0 and 23 (inclusive)."
  }

  validation {
    condition     = contains(["stable", "canary", "week5"], var.postgres_maintenance_window.update_track)
    error_message = "`update_track` must be either 'canary', 'stable', or 'week5'."
  }
}

variable "postgres_insights_config" {
  type = object({
    query_insights_enabled  = bool
    query_plans_per_minute  = number
    query_string_length     = number
    record_application_tags = bool
    record_client_address   = bool
  })
  description = "Configuration settings for Cloud SQL for PostgreSQL insights."
  default = {
    query_insights_enabled  = false
    query_plans_per_minute  = 5
    query_string_length     = 1024
    record_application_tags = false
    record_client_address   = false
  }
}

#------------------------------------------------------------------------------
# Google Cloud Storage (GCS) bucket
#------------------------------------------------------------------------------
variable "gcs_location" {
  type        = string
  description = "Location of TFE GCS bucket to create."
  default     = "US"

  validation {
    condition     = var.gcs_storage_class == "MULTI_REGIONAL" ? contains(["US", "EU", "ASIA"], var.gcs_location) : true
    error_message = "Supported values are 'US', 'EU', and 'ASIA' when `gcs_storage_class` is `MULTI_REGIONAL`."
  }
}

variable "gcs_storage_class" {
  type        = string
  description = "Storage class of TFE GCS bucket."
  default     = "MULTI_REGIONAL"
}

variable "gcs_uniform_bucket_level_access" {
  type        = bool
  description = "Boolean to enable uniform bucket level access on TFE GCS bucket."
  default     = true
}

variable "gcs_force_destroy" {
  type        = bool
  description = "Boolean indicating whether to allow force destroying the TFE GCS bucket. GCS bucket can be destroyed if it is not empty when `true`."
  default     = false
}

variable "gcs_versioning_enabled" {
  type        = bool
  description = "Boolean to enable versioning on TFE GCS bucket."
  default     = true
}

#------------------------------------------------------------------------------
# Redis
#------------------------------------------------------------------------------
variable "redis_tier" {
  type        = string
  description = "The service tier of the Redis instance. Set to `STANDARD_HA` for high availability."
  default     = "STANDARD_HA"
}

variable "redis_version" {
  type        = string
  description = "The version of Redis software."
  default     = "REDIS_7_2"
}

variable "redis_memory_size_gb" {
  type        = number
  description = "The size of the Redis instance in GiB."
  default     = 6
}

variable "redis_auth_enabled" {
  type        = bool
  description = "Boolean to enable authentication on Redis instance."
  default     = true
}

variable "redis_transit_encryption_mode" {
  type        = string
  description = "Determines transit encryption (TLS) mode for Redis instance."
  default     = "DISABLED"

  validation {
    condition     = var.redis_transit_encryption_mode == "SERVER_AUTHENTICATION" || var.redis_transit_encryption_mode == "DISABLED"
    error_message = "Value must either be 'SERVER_AUTHENTICATION' or 'DISABLED'."
  }
}

variable "redis_connect_mode" {
  type        = string
  description = "Network connection mode for Redis instance."
  default     = "PRIVATE_SERVICE_ACCESS"

  validation {
    condition     = var.redis_connect_mode == "PRIVATE_SERVICE_ACCESS" || var.redis_connect_mode == "DIRECT_PEERING"
    error_message = "Invalid value. Valid values are 'PRIVATE_SERVICE_ACCESS' or 'DIRECT_PEERING'."
  }
}

#------------------------------------------------------------------------------
# KMS customer managed encryption keys (CMEK)
#------------------------------------------------------------------------------
variable "postgres_kms_keyring_name" {
  type        = string
  description = "Name of Cloud KMS Key Ring that contains KMS key to use for Cloud SQL for PostgreSQL. Geographic location (region) of key ring must match the location of the TFE Cloud SQL for PostgreSQL database instance."
  default     = null
}

variable "postgres_kms_cmek_name" {
  type        = string
  description = "Name of Cloud KMS customer managed encryption key (CMEK) to use for Cloud SQL for PostgreSQL database instance."
  default     = null
}

variable "gcs_kms_keyring_name" {
  type        = string
  description = "Name of Cloud KMS key ring that contains KMS customer managed encryption key (CMEK) to use for TFE GCS bucket encryption. Geographic location (region) of the key ring must match the location of the TFE GCS bucket."
  default     = null
}

variable "gcs_kms_cmek_name" {
  type        = string
  description = "Name of Cloud KMS customer managed encryption key (CMEK) to use for TFE GCS bucket encryption."
  default     = null
}

variable "redis_kms_keyring_name" {
  type        = string
  description = "Name of Cloud KMS key ring that contains KMS customer managed encryption key (CMEK) to use for TFE Redis instance. Geographic location (region) of key ring must match the location of the TFE Redis instance."
  default     = null
}

variable "redis_kms_cmek_name" {
  type        = string
  description = "Name of Cloud KMS customer managed encryption key (CMEK) to use for TFE Redis instance."
  default     = null
}

#------------------------------------------------------------------------------
# Log forwarding
#------------------------------------------------------------------------------
variable "tfe_log_forwarding_enabled" {
  type        = bool
  description = "Boolean to enable TFE log forwarding configuration via Fluent Bit."
  default     = false
}

variable "log_fwd_destination_type" {
  type        = string
  description = "Type of log forwarding destination for Fluent Bit. Valid values are `stackdriver` or `custom`."
  default     = "stackdriver"

  validation {
    condition     = contains(["stackdriver", "custom"], var.log_fwd_destination_type)
    error_message = "Supported values are `stackdriver` or `custom`."
  }
}

variable "custom_fluent_bit_config" {
  type        = string
  description = "Custom Fluent Bit configuration for log forwarding. Only valid when `tfe_log_forwarding_enabled` is `true` and `log_fwd_destination_type` is `custom`."
  default     = null
}