# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#---------------------------------------------------------------------------
# Common
#------------------------------------------------------------------------------
variable "project_id" {
  type        = string
  description = "ID of GCP Project to create resources in."
}
variable "region" {
  type        = string
  description = "Region of GCP Project to create resources in."
}
variable "friendly_name_prefix" {
  type        = string
  description = "Friendly name prefix used for uniquely naming resources."
  validation {
    condition     = !strcontains(var.friendly_name_prefix, "tfe")
    error_message = "The prefix should not contain 'tfe'."
  }
}

variable "common_labels" {
  type        = map(string)
  description = "Common labels to apply to GCP resources."
  default     = {}
}

variable "is_secondary_region" {
  type        = bool
  description = "Boolean indicating whether this TFE deployment is in the 'primary' region or 'secondary' region."
  default     = false
}

#------------------------------------------------------------------------------
# TFE bootstrap settings
#------------------------------------------------------------------------------
variable "tfe_license_secret_id" {
  type        = string
  description = "ID of Secrets Manager secret for TFE license file."
}

variable "tfe_tls_cert_secret_id" {
  type        = string
  description = "ID of Secrets Manager secret for TFE TLS certificate in PEM format. Secret must be stored as a base64-encoded string."
}

variable "tfe_tls_privkey_secret_id" {
  type        = string
  description = "ID of Secrets Manager secret for TFE TLS private key in PEM format. Secret must be stored as a base64-encoded string."
}

variable "tfe_tls_ca_bundle_secret_id" {
  type        = string
  description = "ID of Secrets Manager secret for private/custom TLS Certificate Authority (CA) bundle in PEM format. Secret must be stored as a base64-encoded string."
}

variable "tfe_encryption_password_secret_id" {
  type        = string
  description = "ID of Secrets Manager secret for TFE encryption password."
}

variable "tfe_image_repository_url" {
  type        = string
  description = "Repository for the TFE image. Only set this if you are hosting the TFE container image in your own custom repository."
  default     = "images.releases.hashicorp.com"
}

variable "tfe_image_name" {
  type        = string
  description = "Name of the TFE container image. Only set this if you are hosting the TFE container image in your own custom repository."
  default     = "hashicorp/terraform-enterprise"
}

variable "tfe_image_tag" {
  type        = string
  description = "Tag for the TFE image. This represents the version of TFE to deploy."
  default     = "v202402-2"
}

variable "tfe_image_repository_username" {
  type        = string
  description = "Username for container registry where TFE container image is hosted."
  default     = "terraform"
}

variable "tfe_image_repository_password" {
  type        = string
  description = "Pasword for container registry where TFE container image is hosted. Leave null if using the default TFE registry as the default password is the TFE license file."
  default     = null
}

variable "docker_version" {
  type        = string
  description = "Full Version version string for OS choice while installing Docker to install on TFE GCP instances."
  default     = "26.1.4-1"
}

variable "tfe_run_pipeline_image_ecr_repo_name" {
  type        = string
  description = "Name of the ECR repository containing your custom TFE run pipeline image."
  default     = null
}

#------------------------------------------------------------------------------
# TFE Configuration Settings
#------------------------------------------------------------------------------
variable "tfe_fqdn" {
  type        = string
  description = "Fully qualified domain name of TFE instance. This name should resolve to the load balancer IP address and will be what clients use to access TFE."
}

variable "tfe_capacity_concurrency" {
  type        = number
  description = "Maximum number of concurrent Terraform runs to allow on a TFE node."
  default     = 10
}

variable "tfe_capacity_cpu" {
  type        = number
  description = "Maxium number of CPU cores that a Terraform run is allowed to consume in TFE. Set to `0` for no limit."
  default     = 0
}

variable "tfe_capacity_memory" {
  type        = number
  description = "Maximum amount of memory (in MiB) that a Terraform run is allowed to consume in TFE."
  default     = 2048
}

variable "tfe_license_reporting_opt_out" {
  type        = bool
  description = "Boolean to opt out of license reporting."
  default     = false
}

variable "tfe_operational_mode" {
  type        = string
  description = "Operational mode for TFE."
  default     = "active-active"

  validation {
    condition     = contains(["active-active", "disk", "external"], var.tfe_operational_mode)
    error_message = "Value must be `disk`, `external` or `active-active`."
  }
}

variable "tfe_run_pipeline_image" {
  type        = string
  description = "Name of the Docker image to use for the run pipeline driver."
  default     = null
}

variable "tfe_metrics_enable" {
  type        = bool
  description = "Boolean to enable metrics."
  default     = false
}

variable "tfe_metrics_http_port" {
  type        = number
  description = "HTTP port for TFE metrics scrape."
  default     = 9090
}

variable "tfe_metrics_https_port" {
  type        = number
  description = "HTTPS port for TFE metrics scrape."
  default     = 9091
}

variable "tfe_tls_enforce" {
  type        = bool
  description = "Boolean to enforce TLS."
  default     = false
}

variable "tfe_vault_disable_mlock" {
  type        = bool
  description = "Boolean to disable mlock for internal Vault."
  default     = false
}

variable "tfe_hairpin_addressing" {
  type        = bool
  description = "Boolean to enable hairpin addressing for Layer 4 load balancer with loopback prevention. Only valid when `lb_is_internal` is `false`, as hairpin addressing will automatically be enabled when `lb_is_internal` is `true`, regardless of this setting."
  default     = true
}

variable "tfe_run_pipeline_docker_network" {
  type        = string
  description = "Docker network where the containers that execute Terraform runs will be created. The network must already exist, it will not be created automatically. Leave null to use the default network."
  default     = null
}
variable "tfe_mounted_disk_path" {
  type        = string
  description = "(Optional) Path for mounted disk source, defaults to /opt/hashicorp/terraform-enterprise"
  default     = "/opt/hashicorp/terraform-enterprise/data"
}
#------------------------------------------------------------------------------
#  IAC bootstrap settings
#------------------------------------------------------------------------------

variable "tfe_iact_subnets" {
  #	https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/configuration#tfe_iact_subnets
  type        = string
  description = "Comma-separated list of subnets in CIDR notation that are allowed to retrieve the initial admin creation token via the API, or GUI"
  default     = ""
}
variable "tfe_iact_time_limit" {
  # https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/configuration#tfe_iact_time_limit
  type        = string
  description = "Number of minutes that the initial admin creation token can be retrieved via the API after the application starts. Defaults to 60"
  default     = "60"

}
variable "tfe_iact_trusted_proxies" {
  #https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/configuration#tfe_iact_trusted_proxies
  type        = string
  description = "Comma-separated list of subnets in CIDR notation that are allowed to retrieve the initial admin creation token via the API, or GUI"
  default     = ""
}

#------------------------------------------------------------------------------
# Log Forwarding
#------------------------------------------------------------------------------
variable "tfe_log_forwarding_enabled" {
  type        = bool
  description = "Boolean to enable TFE log forwarding feature."
  default     = false
}
variable "log_fwd_destination_type" {
  type        = string
  description = "Type of log forwarding destination. Valid values are `stackdriver` or `custom`."
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

#-----------------------------------------------------------------------------------
# Networking
#-----------------------------------------------------------------------------------
variable "network" {
  type        = string
  description = "The VPC network to host the cluster in"
}

variable "network_project_id" {
  type        = string
  description = "ID of GCP Project where the existing VPC resides if it is different than the default project."
  default     = null
}
variable "subnet" {
  type        = string
  description = "Existing VPC subnet for TFE instance(s) and optionally TFE frontend load balancer."
}

variable "http_proxy" {
  type        = string
  description = "Proxy address to configure for TFE to use for outbound connections."
  default     = ""
}

variable "extra_no_proxy" {
  type        = string
  description = "A comma-separated string of hostnames or IP addresses to configure for TFE no_proxy list."
  default     = ""
}

variable "load_balancing_scheme" {
  type        = string
  description = "Determines whether load balancer is internal-facing or external-facing."
  default     = "external"

  validation {
    condition     = contains(["external", "internal"], var.load_balancing_scheme)
    error_message = "Supported values are `external`, `internal`."
  }
}

variable "create_cloud_dns_record" {
  type        = bool
  description = "Boolean to create Google Cloud DNS record for `tfe_fqdn` resolving to load balancer IP. `cloud_dns_managed_zone` is required when `true`."
  default     = false
}

variable "cloud_dns_managed_zone" {
  type        = string
  description = "Zone name to create TFE Cloud DNS record in if `create_cloud_dns_record` is set to `true`."
  default     = null
}

#-----------------------------------------------------------------------------------
# Firewall
#-----------------------------------------------------------------------------------
variable "cidr_ingress_ssh_allow" {
  type        = list(string)
  description = "CIDR ranges to allow SSH traffic inbound to TFE instance(s) via IAP tunnel."
  default     = ["10.0.0.0/16"]

}

variable "cidr_ingress_https_allow" {
  type        = list(string)
  description = "CIDR ranges to allow HTTPS traffic inbound to TFE instance(s)."
  default     = ["0.0.0.0/0"]
}

#-----------------------------------------------------------------------------------
# Encryption Keys (KMS)
#-----------------------------------------------------------------------------------
variable "gcs_bucket_keyring_name" {
  type        = string
  description = "Name of KMS Key Ring that contains KMS key to use for gcs bucket encryption. Geographic location of key ring must match `gcs_bucket_location`."
  default     = null
}

variable "gcs_bucket_key_name" {
  type        = string
  description = "Name of KMS Key to use for gcs bucket encryption."
  default     = null
}

variable "postgres_keyring_name" {
  type        = string
  description = "Name of KMS Key Ring that contains KMS key to use for Cloud SQL for PostgreSQL database encryption. Geographic location of key ring must match location of database instance."
  default     = null
}

variable "postgres_key_name" {
  type        = string
  description = "Name of KMS Key to use for Cloud SQL for PostgreSQL encryption."
  default     = null
}

#-----------------------------------------------------------------------------------
# Compute
#-----------------------------------------------------------------------------------
variable "image_project" {
  type        = string
  description = "ID of project in which the resource belongs."
  default     = "ubuntu-os-cloud"
}

variable "image_name" {
  type        = string
  description = "VM image for TFE instance(s)."
  default     = "ubuntu-2404-noble-amd64-v20240607"
}

variable "machine_type" {
  type        = string
  description = "(Optional string) Size of machine to create. Default `n2-standard-4` from https://cloud.google.com/compute/docs/machine-resource."
  default     = "n2-standard-4"
  # regional dependancy https://gcloud-compute.com/n2-standard-4.html
}

variable "disk_size_gb" {
  type        = number
  description = "Size in Gigabytes of root disk of TFE instance(s)."
  default     = 50
}

variable "instance_count" {
  type        = number
  description = "Target size of Managed Instance Group for number of TFE instances to run. Only specify a value greater than 1 if `enable_active_active` is set to `true`."
  default     = 1
}

variable "initial_delay_sec" {
  type        = number
  description = "The number of seconds that the managed instance group waits before it applies autohealing policies to new instances or recently recreated instances"
  default     = 1200
}
variable "tfe_user_data_template" {
  type        = string
  description = "(optional) File name for user_data_template.sh.tpl file in `./templates folder` no path required"
  default     = "tfe_user_data.sh.tpl"
  validation {
    condition     = can(fileexists("../../templates/${var.tfe_user_data_template}") || fileexists("./templates/${var.tfe_user_data_template}"))
    error_message = "File `./templates/${var.tfe_user_data_template}` not found or not readable"
  }
}
variable "enable_iap" {
  type        = bool
  default     = true
  description = "(Optional bool) Enable https://cloud.google.com/iap/docs/using-tcp-forwarding#console, defaults to `true`. "
}
#-----------------------------------------------------------------------------------
# Cloud SQL for PostgreSQL
#-----------------------------------------------------------------------------------
variable "tfe_database_password_secret_id" {
  type        = string
  description = "ID of secret stored in GCP Secrets Manager containing TFE install secrets."
  default     = null
  validation {
    condition     = contains(["active-active", "external"], var.tfe_operational_mode) ? var.tfe_database_password_secret_id != null : true
    error_message = "`tfe_database_password_secret_id` must be provided when var.tfe_operational_mode is set to one of `active-active` or `external` "
  }
}

variable "postgres_extra_params" {
  type        = string
  description = "Parameter keyword/value pairs to support additional PostgreSQL parameters that may be necessary."
  default     = "sslmode=require"
}

variable "postgres_version" {
  type        = string
  description = "PostgreSQL version to use."
  default     = "POSTGRES_15"
}

variable "postgres_availability_type" {
  type        = string
  description = "Availability type of Cloud SQL PostgreSQL instance."
  default     = "REGIONAL"
}

variable "postgres_machine_type" {
  type        = string
  description = "Machine size of Cloud SQL PostgreSQL instance."
  default     = "db-custom-4-16384"
}

variable "postgres_disk_size" {
  type        = number
  description = "Size in GB of PostgreSQL disk."
  default     = 50
}

variable "postgres_backup_start_time" {
  type        = string
  description = "HH:MM time format indicating when daily automatic backups should run."
  default     = "00:00"
}

#-----------------------------------------------------------------------------------
# Cloud Storage Bucket
#-----------------------------------------------------------------------------------
variable "gcs_bucket_location" {
  type        = string
  description = "[Optional one of `ca`,`us`, `europe`, `asia`,`au`,`nam-eur-asia1`] Location for GCS bucket.  All regions are multi-region https://cloud.google.com/kms/docs/locations"
  default     = "us"
  validation {
    condition     = can(anytrue([contains(["ca", "us", "europe", "asia", "au", "nam-eur-asia1"], var.gcs_bucket_location), var.gcs_bucket_location == null]))
    error_message = "Supported values are `ca`,`us`, `europe`, `asia`,`au`,`nam-eur-asia1`; all regions are multi-region https://cloud.google.com/kms/docs/locations"
  }
}
variable "gcs_force_destroy" {
  type        = bool
  description = "Boolean indicating whether to allow force destroying the gcs bucket. If set to `true` the gcs bucket can be destroyed if it is not empty."
  default     = false
}

#-----------------------------------------------------------------------------------
# Redis
#-----------------------------------------------------------------------------------
variable "enable_active_active" {
  type        = bool
  description = "Boolean indicating whether to deploy TFE in the Active:Active architecture using external Redis."
  default     = false
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
  default     = "REDIS_6_X"
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
  description = "Boolean to enable TLS for Redis instance."
  default     = "DISABLED"
}

variable "redis_connect_mode" {
  type        = string
  description = "Network connection mode for Redis instance."
  default     = "PRIVATE_SERVICE_ACCESS"

  validation {
    condition = contains(["PRIVATE_SERVICE_ACCESS", "DIRECT_PEERING"], var.redis_connect_mode)
    #condition     = var.redis_connect_mode == "PRIVATE_SERVICE_ACCESS" || var.redis_connect_mode == "DIRECT_PEERING"
    error_message = "Invalid value for redis_connect_mode. Allowed values are 'PRIVATE_SERVICE_ACCESS' or 'DIRECT_PEERING'."
  }
}

#-----------------------------------------------------------------------------------
# Verbose
#-----------------------------------------------------------------------------------

variable "verbose_template" {
  type        = bool
  description = "[Optional bool] Enables the user_data template to be output in full for debug and review purposes."
  default     = false
}

