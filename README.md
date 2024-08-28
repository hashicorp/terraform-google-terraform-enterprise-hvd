# Terraform Enterprise HVD on GCP GCE

Terraform module aligned with HashiCorp Validated Designs (HVD) to deploy Terraform Enterprise (TFE) on Google Cloud Platform (GCP) using Compute Engine instances with a container runtime. This module defaults to deploying TFE in the `active-active` [operational mode](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/operation-modes), but `external` is also supported. Docker is currently the only supported container runtime, but Podman support is being added.

![TFE on Google](https://raw.githubusercontent.com/hashicorp/terraform-google-terraform-enterprise-hvd/main/docs/images/architecture-logical-active-active.png)

## Prerequisites

### General

- TFE license file (_e.g._ `terraform.hclic`)
- Terraform CLI `>= 1.9` installed on clients/workstations that will be used to deploy TFE
- General understanding of how to use Terraform (Community Edition)
- General understanding of how to use GCP
- `git` CLI and Visual Studio Code editor installed on workstations are strongly recommended
- GCP projeect that TFE will be deployed in with permissions to provision these [resources](#resources) via Terraform CLI
- (Optional) GCP GCS bucket for [GCS remote state backend](https://developer.hashicorp.com/terraform/language/settings/backends/gcs) that will be used to manage the Terraform state of this TFE deployment (out-of-band from the TFE application) via Terraform CLI (Community Edition)

### Networking

- GCP network VPC and the following subnets:
  - Load balancer subnetwork IDS (can be the same as Compute Engine (CE) subnets if desirable).
- (Optional) GCS VPC Endpoint configured within VPC.
- (Optional) GCS Hosted Zone for TFE DNS record creation.
- Security groups. This module will create the:
  - necessary security groups and attach them to the applicable resources.
  - service accounts and assign them access to the provided secrets
  - firewall entries.
  - Ensure the [TFE ingress requirements](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#ingress) are met.
  - Ensure the [TFE egress requirements](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#egress) are met.

### Secrets Manager

GCP Secrets Manager "TFE bootstrap" secrets:
  - **TFE license file** - raw contents of file stored as a plaintext secret.
  - **TFE encryption password** - random characters stored as plaintext secret.
  - **RDS (PostgreSQL) database password** - random characters stored as plaintext secret.
  - (Optional) **Redis password** - random characters stored as a plaintext secret.
  - **TFE TLS certificate** - file in PEM format, base64-encoded into a string, and stored as a plaintext secret.
  - **TFE TLS certificate private key** - file in PEM format, base64-encoded into a string, and stored as a plaintext secret.
  - **TLS CA bundle** - file in PEM format, base64-encoded into a string, and stored as a plaintext secret.

### Compute

One of the following mechanisms for shell access to TFE GC instances:

  - Ability to enable [GCP IAP](https://cloud.google.com/iap/docs/using-tcp-forwarding#console) (this module supports this via a boolean input variable).
 -  GC SSH Key Pair

### Log Forwarding (optional)

One of the following logging destinations:
  - Stackdriver
  - A custom fluent bit configuration that will forward logs to custom destination.

---
## Usage

1. Create/configure/validate the applicable [prerequisites](#prerequisites).

2. Nested within the [examples](./examples/) directory are subdirectories containing ready-made Terraform configurations for example scenarios on how to call and deploy this module. To get started, choose the example scenario that most closely matches your requirements. You can customize your deployment later by adding additional module [inputs](#inputs) as you see fit (see the [Deployment-Customizations](./docs/deployment-customizations.md) doc for more details).

3. Copy all of the Terraform files from your example scenario of choice into a new destination directory to create your Terraform configuration that will manage your TFE deployment. This is a common directory structure for managing multiple TFE deployments:

    ```
    .
    └── environments
        ├── production
        │   ├── backend.tf
        │   ├── main.tf
        │   ├── outputs.tf
        │   ├── terraform.tfvars
        │   └── variables.tf
        └── sandbox
            ├── backend.tf
            ├── main.tf
            ├── outputs.tf
            ├── terraform.tfvars
            └── variables.tf
    ```

    >📝 Note: in this example, the user will have two separate TFE deployments; one for their `sandbox` environment, and one for their `production` environment. This is recommended, but not required.

4. (Optional) Uncomment and update the  [GCS remote state backend](https://developer.hashicorp.com/terraform/language/settings/backends/gcs)  configuration provided in the `backend.tf` file with your own custom values. While this step is highly recommended, it is technically not required to use a remote backend config for your TFE deployment.

5. Populate your own custom values into the `terraform.tfvars.example` file that was provided, and remove the `.example` file extension such that the file is now named `terraform.tfvars`.

6. Navigate to the directory of your newly created Terraform configuration for your TFE deployment, and run `terraform init`, `terraform plan`, and `terraform apply`.

7. After your `terraform apply` finishes successfully, you can monitor the installation progress by connecting to your TFE gcp instance shell via SSH or gcp IAP and observing the meta data script(user_data) logs:<br>

   Higher-level logs:

   ```sh
   tail -f /var/log/tfe-cloud-init.log
   ```

   Lower-level logs:

   ```sh
   sudo journalctl -u google-startup-scripts.service -f
   ```

   >📝 Note: the `-f` argument is to follow the logs as they append in real-time, and is optional. You may remove the `-f` for a static view.

   The log files should display the following message after the cloud-init (user_data) script finishes successfully:

   ```sh
   [INFO] tfe_user_data script finished successfully!
   ```

8. After the cloud-init (user_data) script finishes successfully, while still connected to the TFE CE instance shell, you can check the health status of TFE:

   ```sh
   cd /etc/tfe
   sudo docker compose exec terraform-enterprise tfe-health-check-status
   ```

9. Follow the steps to [here](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/initial-admin-user) to create the TFE initial admin user.

- the module includes outputs for the initial admin user token retrieval.

---

## Docs

Below are links to docs pages related to deployment customizations as well as managing day 2 operations of your TFE instance.

- [deployment-customizations.md](./docs/deployment-customizations.md)
- [operations.md](./docs/operations.md)
- [tfe-tls-cert-rotation.md](./docs/tfe-tls-cert-rotation.md)
- [tfe-config-settings.md](./docs/tfe-config-settings.md)
- [tfe-version-upgrades.md](./docs/tfe-version-upgrades.md)
- [troubleshooting.md](./docs/troubleshooting.md)

---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 5.39 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 5.39 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~> 5.39 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | ~> 5.39 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.6 |

## Resources

| Name | Type |
|------|------|
| [google-beta_google_project_service_identity.gcp_sa_cloud_sql](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_project_service_identity) | resource |
| [google-beta_google_sql_database_instance.tfe](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_sql_database_instance) | resource |
| [google_compute_address.tfe_frontend_lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_firewall.allow_https](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_iap](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_prometheus](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.health_checks](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.tfe_self](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_forwarding_rule.tfe_frontend_lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_global_address.postgres_private_ip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_health_check.tfe_auto_healing](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check) | resource |
| [google_compute_instance_template.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_region_backend_service.tfe_backend_lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_health_check.tfe_backend_lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_health_check) | resource |
| [google_compute_region_instance_group_manager.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager) | resource |
| [google_dns_record_set.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_kms_crypto_key_iam_member.gcs_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_crypto_key_iam_member.gcs_bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_crypto_key_iam_member.postgres](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_crypto_key_iam_member.postgres_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_crypto_key_iam_member.postgres_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_project_iam_member.stackdriver](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_redis_instance.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance) | resource |
| [google_secret_manager_secret_iam_member.ca_bundle](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_iam_member.tfe_cert](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_iam_member.tfe_encryption_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_iam_member.tfe_license](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_iam_member.tfe_privkey](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_service_account.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_key.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_key) | resource |
| [google_service_networking_connection.postgres_endpoint](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection) | resource |
| [google_sql_database.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database) | resource |
| [google_sql_user.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) | resource |
| [google_storage_bucket.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.tfe_bucket_object_admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.tfe_bucket_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [random_id.gcs_bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_id.postgres_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [google_client_config.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_compute_image.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_image) | data source |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_subnetwork.subnet](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_zones.up](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones) | data source |
| [google_dns_managed_zone.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/dns_managed_zone) | data source |
| [google_kms_crypto_key.gcs_bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_crypto_key) | data source |
| [google_kms_crypto_key.postgres](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_crypto_key) | data source |
| [google_kms_key_ring.gcs_bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_key_ring) | data source |
| [google_kms_key_ring.postgres](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_key_ring) | data source |
| [google_secret_manager_secret_version.tfe_database_password_secret_id](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version) | data source |
| [google_storage_project_service_account.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_friendly_name_prefix"></a> [friendly\_name\_prefix](#input\_friendly\_name\_prefix) | Friendly name prefix used for uniquely naming resources. | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | The VPC network to host the cluster in | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | ID of GCP Project to create resources in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of GCP Project to create resources in. | `string` | n/a | yes |
| <a name="input_subnet"></a> [subnet](#input\_subnet) | Existing VPC subnet for TFE instance(s) and optionally TFE frontend load balancer. | `string` | n/a | yes |
| <a name="input_tfe_encryption_password_secret_id"></a> [tfe\_encryption\_password\_secret\_id](#input\_tfe\_encryption\_password\_secret\_id) | ID of Secrets Manager secret for TFE encryption password. | `string` | n/a | yes |
| <a name="input_tfe_fqdn"></a> [tfe\_fqdn](#input\_tfe\_fqdn) | Fully qualified domain name of TFE instance. This name should resolve to the load balancer IP address and will be what clients use to access TFE. | `string` | n/a | yes |
| <a name="input_tfe_license_secret_id"></a> [tfe\_license\_secret\_id](#input\_tfe\_license\_secret\_id) | ID of Secrets Manager secret for TFE license file. | `string` | n/a | yes |
| <a name="input_tfe_tls_ca_bundle_secret_id"></a> [tfe\_tls\_ca\_bundle\_secret\_id](#input\_tfe\_tls\_ca\_bundle\_secret\_id) | ID of Secrets Manager secret for private/custom TLS Certificate Authority (CA) bundle in PEM format. Secret must be stored as a base64-encoded string. | `string` | n/a | yes |
| <a name="input_tfe_tls_cert_secret_id"></a> [tfe\_tls\_cert\_secret\_id](#input\_tfe\_tls\_cert\_secret\_id) | ID of Secrets Manager secret for TFE TLS certificate in PEM format. Secret must be stored as a base64-encoded string. | `string` | n/a | yes |
| <a name="input_tfe_tls_privkey_secret_id"></a> [tfe\_tls\_privkey\_secret\_id](#input\_tfe\_tls\_privkey\_secret\_id) | ID of Secrets Manager secret for TFE TLS private key in PEM format. Secret must be stored as a base64-encoded string. | `string` | n/a | yes |
| <a name="input_cidr_ingress_https_allow"></a> [cidr\_ingress\_https\_allow](#input\_cidr\_ingress\_https\_allow) | CIDR ranges to allow HTTPS traffic inbound to TFE instance(s). | `list(string)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| <a name="input_cidr_ingress_ssh_allow"></a> [cidr\_ingress\_ssh\_allow](#input\_cidr\_ingress\_ssh\_allow) | CIDR ranges to allow SSH traffic inbound to TFE instance(s) via IAP tunnel. | `list(string)` | <pre>[<br>  "10.0.0.0/16"<br>]</pre> | no |
| <a name="input_cloud_dns_managed_zone"></a> [cloud\_dns\_managed\_zone](#input\_cloud\_dns\_managed\_zone) | Zone name to create TFE Cloud DNS record in if `create_cloud_dns_record` is set to `true`. | `string` | `null` | no |
| <a name="input_common_labels"></a> [common\_labels](#input\_common\_labels) | Common labels to apply to GCP resources. | `map(string)` | `{}` | no |
| <a name="input_create_cloud_dns_record"></a> [create\_cloud\_dns\_record](#input\_create\_cloud\_dns\_record) | Boolean to create Google Cloud DNS record for `tfe_fqdn` resolving to load balancer IP. `cloud_dns_managed_zone` is required when `true`. | `bool` | `false` | no |
| <a name="input_custom_fluent_bit_config"></a> [custom\_fluent\_bit\_config](#input\_custom\_fluent\_bit\_config) | Custom Fluent Bit configuration for log forwarding. Only valid when `tfe_log_forwarding_enabled` is `true` and `log_fwd_destination_type` is `custom`. | `string` | `null` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Size in Gigabytes of root disk of TFE instance(s). | `number` | `50` | no |
| <a name="input_docker_version"></a> [docker\_version](#input\_docker\_version) | Full Version version string for OS choice while installing Docker to install on TFE GCP instances. | `string` | `"26.1.4-1"` | no |
| <a name="input_enable_active_active"></a> [enable\_active\_active](#input\_enable\_active\_active) | Boolean indicating whether to deploy TFE in the Active:Active architecture using external Redis. | `bool` | `false` | no |
| <a name="input_enable_iap"></a> [enable\_iap](#input\_enable\_iap) | (Optional bool) Enable https://cloud.google.com/iap/docs/using-tcp-forwarding#console, defaults to `true`. | `bool` | `true` | no |
| <a name="input_extra_no_proxy"></a> [extra\_no\_proxy](#input\_extra\_no\_proxy) | A comma-separated string of hostnames or IP addresses to configure for TFE no\_proxy list. | `string` | `""` | no |
| <a name="input_gcs_bucket_key_name"></a> [gcs\_bucket\_key\_name](#input\_gcs\_bucket\_key\_name) | Name of KMS Key to use for gcs bucket encryption. | `string` | `null` | no |
| <a name="input_gcs_bucket_keyring_name"></a> [gcs\_bucket\_keyring\_name](#input\_gcs\_bucket\_keyring\_name) | Name of KMS Key Ring that contains KMS key to use for gcs bucket encryption. Geographic location of key ring must match `gcs_bucket_location`. | `string` | `null` | no |
| <a name="input_gcs_bucket_location"></a> [gcs\_bucket\_location](#input\_gcs\_bucket\_location) | [Optional one of `ca`,`us`, `europe`, `asia`,`au`,`nam-eur-asia1`] Location for GCS bucket.  All regions are multi-region https://cloud.google.com/kms/docs/locations | `string` | `"us"` | no |
| <a name="input_gcs_force_destroy"></a> [gcs\_force\_destroy](#input\_gcs\_force\_destroy) | Boolean indicating whether to allow force destroying the gcs bucket. If set to `true` the gcs bucket can be destroyed if it is not empty. | `bool` | `false` | no |
| <a name="input_http_proxy"></a> [http\_proxy](#input\_http\_proxy) | Proxy address to configure for TFE to use for outbound connections. | `string` | `""` | no |
| <a name="input_image_name"></a> [image\_name](#input\_image\_name) | VM image for TFE instance(s). | `string` | `"ubuntu-2404-noble-amd64-v20240607"` | no |
| <a name="input_image_project"></a> [image\_project](#input\_image\_project) | ID of project in which the resource belongs. | `string` | `"ubuntu-os-cloud"` | no |
| <a name="input_initial_delay_sec"></a> [initial\_delay\_sec](#input\_initial\_delay\_sec) | The number of seconds that the managed instance group waits before it applies autohealing policies to new instances or recently recreated instances | `number` | `1200` | no |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | Target size of Managed Instance Group for number of TFE instances to run. Only specify a value greater than 1 if `enable_active_active` is set to `true`. | `number` | `1` | no |
| <a name="input_is_secondary_region"></a> [is\_secondary\_region](#input\_is\_secondary\_region) | Boolean indicating whether this TFE deployment is in the 'primary' region or 'secondary' region. | `bool` | `false` | no |
| <a name="input_load_balancing_scheme"></a> [load\_balancing\_scheme](#input\_load\_balancing\_scheme) | Determines whether load balancer is internal-facing or external-facing. | `string` | `"external"` | no |
| <a name="input_log_fwd_destination_type"></a> [log\_fwd\_destination\_type](#input\_log\_fwd\_destination\_type) | Type of log forwarding destination. Valid values are `stackdriver` or `custom`. | `string` | `"stackdriver"` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | (Optional string) Size of machine to create. Default `n2-standard-4` from https://cloud.google.com/compute/docs/machine-resource. | `string` | `"n2-standard-4"` | no |
| <a name="input_network_project_id"></a> [network\_project\_id](#input\_network\_project\_id) | ID of GCP Project where the existing VPC resides if it is different than the default project. | `string` | `null` | no |
| <a name="input_postgres_availability_type"></a> [postgres\_availability\_type](#input\_postgres\_availability\_type) | Availability type of Cloud SQL PostgreSQL instance. | `string` | `"REGIONAL"` | no |
| <a name="input_postgres_backup_start_time"></a> [postgres\_backup\_start\_time](#input\_postgres\_backup\_start\_time) | HH:MM time format indicating when daily automatic backups should run. | `string` | `"00:00"` | no |
| <a name="input_postgres_disk_size"></a> [postgres\_disk\_size](#input\_postgres\_disk\_size) | Size in GB of PostgreSQL disk. | `number` | `50` | no |
| <a name="input_postgres_extra_params"></a> [postgres\_extra\_params](#input\_postgres\_extra\_params) | Parameter keyword/value pairs to support additional PostgreSQL parameters that may be necessary. | `string` | `"sslmode=require"` | no |
| <a name="input_postgres_key_name"></a> [postgres\_key\_name](#input\_postgres\_key\_name) | Name of KMS Key to use for Cloud SQL for PostgreSQL encryption. | `string` | `null` | no |
| <a name="input_postgres_keyring_name"></a> [postgres\_keyring\_name](#input\_postgres\_keyring\_name) | Name of KMS Key Ring that contains KMS key to use for Cloud SQL for PostgreSQL database encryption. Geographic location of key ring must match location of database instance. | `string` | `null` | no |
| <a name="input_postgres_machine_type"></a> [postgres\_machine\_type](#input\_postgres\_machine\_type) | Machine size of Cloud SQL PostgreSQL instance. | `string` | `"db-custom-4-16384"` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL version to use. | `string` | `"POSTGRES_15"` | no |
| <a name="input_redis_auth_enabled"></a> [redis\_auth\_enabled](#input\_redis\_auth\_enabled) | Boolean to enable authentication on Redis instance. | `bool` | `true` | no |
| <a name="input_redis_connect_mode"></a> [redis\_connect\_mode](#input\_redis\_connect\_mode) | Network connection mode for Redis instance. | `string` | `"PRIVATE_SERVICE_ACCESS"` | no |
| <a name="input_redis_memory_size_gb"></a> [redis\_memory\_size\_gb](#input\_redis\_memory\_size\_gb) | The size of the Redis instance in GiB. | `number` | `6` | no |
| <a name="input_redis_tier"></a> [redis\_tier](#input\_redis\_tier) | The service tier of the Redis instance. Set to `STANDARD_HA` for high availability. | `string` | `"STANDARD_HA"` | no |
| <a name="input_redis_transit_encryption_mode"></a> [redis\_transit\_encryption\_mode](#input\_redis\_transit\_encryption\_mode) | Boolean to enable TLS for Redis instance. | `string` | `"DISABLED"` | no |
| <a name="input_redis_version"></a> [redis\_version](#input\_redis\_version) | The version of Redis software. | `string` | `"REDIS_6_X"` | no |
| <a name="input_tfe_capacity_concurrency"></a> [tfe\_capacity\_concurrency](#input\_tfe\_capacity\_concurrency) | Maximum number of concurrent Terraform runs to allow on a TFE node. | `number` | `10` | no |
| <a name="input_tfe_capacity_cpu"></a> [tfe\_capacity\_cpu](#input\_tfe\_capacity\_cpu) | Maxium number of CPU cores that a Terraform run is allowed to consume in TFE. Set to `0` for no limit. | `number` | `0` | no |
| <a name="input_tfe_capacity_memory"></a> [tfe\_capacity\_memory](#input\_tfe\_capacity\_memory) | Maximum amount of memory (in MiB) that a Terraform run is allowed to consume in TFE. | `number` | `2048` | no |
| <a name="input_tfe_database_password_secret_id"></a> [tfe\_database\_password\_secret\_id](#input\_tfe\_database\_password\_secret\_id) | ID of secret stored in GCP Secrets Manager containing TFE install secrets. | `string` | `null` | no |
| <a name="input_tfe_hairpin_addressing"></a> [tfe\_hairpin\_addressing](#input\_tfe\_hairpin\_addressing) | Boolean to enable hairpin addressing for Layer 4 load balancer with loopback prevention. Only valid when `lb_is_internal` is `false`, as hairpin addressing will automatically be enabled when `lb_is_internal` is `true`, regardless of this setting. | `bool` | `true` | no |
| <a name="input_tfe_iact_subnets"></a> [tfe\_iact\_subnets](#input\_tfe\_iact\_subnets) | Comma-separated list of subnets in CIDR notation that are allowed to retrieve the initial admin creation token via the API, or GUI | `string` | `""` | no |
| <a name="input_tfe_iact_time_limit"></a> [tfe\_iact\_time\_limit](#input\_tfe\_iact\_time\_limit) | Number of minutes that the initial admin creation token can be retrieved via the API after the application starts. Defaults to 60 | `string` | `"60"` | no |
| <a name="input_tfe_iact_trusted_proxies"></a> [tfe\_iact\_trusted\_proxies](#input\_tfe\_iact\_trusted\_proxies) | Comma-separated list of subnets in CIDR notation that are allowed to retrieve the initial admin creation token via the API, or GUI | `string` | `""` | no |
| <a name="input_tfe_image_name"></a> [tfe\_image\_name](#input\_tfe\_image\_name) | Name of the TFE container image. Only set this if you are hosting the TFE container image in your own custom repository. | `string` | `"hashicorp/terraform-enterprise"` | no |
| <a name="input_tfe_image_repository_password"></a> [tfe\_image\_repository\_password](#input\_tfe\_image\_repository\_password) | Pasword for container registry where TFE container image is hosted. Leave null if using the default TFE registry as the default password is the TFE license file. | `string` | `null` | no |
| <a name="input_tfe_image_repository_url"></a> [tfe\_image\_repository\_url](#input\_tfe\_image\_repository\_url) | Repository for the TFE image. Only set this if you are hosting the TFE container image in your own custom repository. | `string` | `"images.releases.hashicorp.com"` | no |
| <a name="input_tfe_image_repository_username"></a> [tfe\_image\_repository\_username](#input\_tfe\_image\_repository\_username) | Username for container registry where TFE container image is hosted. | `string` | `"terraform"` | no |
| <a name="input_tfe_image_tag"></a> [tfe\_image\_tag](#input\_tfe\_image\_tag) | Tag for the TFE image. This represents the version of TFE to deploy. | `string` | `"v202402-2"` | no |
| <a name="input_tfe_license_reporting_opt_out"></a> [tfe\_license\_reporting\_opt\_out](#input\_tfe\_license\_reporting\_opt\_out) | Boolean to opt out of license reporting. | `bool` | `false` | no |
| <a name="input_tfe_log_forwarding_enabled"></a> [tfe\_log\_forwarding\_enabled](#input\_tfe\_log\_forwarding\_enabled) | Boolean to enable TFE log forwarding feature. | `bool` | `false` | no |
| <a name="input_tfe_metrics_enable"></a> [tfe\_metrics\_enable](#input\_tfe\_metrics\_enable) | Boolean to enable metrics. | `bool` | `false` | no |
| <a name="input_tfe_metrics_http_port"></a> [tfe\_metrics\_http\_port](#input\_tfe\_metrics\_http\_port) | HTTP port for TFE metrics scrape. | `number` | `9090` | no |
| <a name="input_tfe_metrics_https_port"></a> [tfe\_metrics\_https\_port](#input\_tfe\_metrics\_https\_port) | HTTPS port for TFE metrics scrape. | `number` | `9091` | no |
| <a name="input_tfe_mounted_disk_path"></a> [tfe\_mounted\_disk\_path](#input\_tfe\_mounted\_disk\_path) | (Optional) Path for mounted disk source, defaults to /opt/hashicorp/terraform-enterprise | `string` | `"/opt/hashicorp/terraform-enterprise/data"` | no |
| <a name="input_tfe_operational_mode"></a> [tfe\_operational\_mode](#input\_tfe\_operational\_mode) | Operational mode for TFE. | `string` | `"active-active"` | no |
| <a name="input_tfe_run_pipeline_docker_network"></a> [tfe\_run\_pipeline\_docker\_network](#input\_tfe\_run\_pipeline\_docker\_network) | Docker network where the containers that execute Terraform runs will be created. The network must already exist, it will not be created automatically. Leave null to use the default network. | `string` | `null` | no |
| <a name="input_tfe_run_pipeline_image"></a> [tfe\_run\_pipeline\_image](#input\_tfe\_run\_pipeline\_image) | Name of the Docker image to use for the run pipeline driver. | `string` | `null` | no |
| <a name="input_tfe_run_pipeline_image_ecr_repo_name"></a> [tfe\_run\_pipeline\_image\_ecr\_repo\_name](#input\_tfe\_run\_pipeline\_image\_ecr\_repo\_name) | Name of the ECR repository containing your custom TFE run pipeline image. | `string` | `null` | no |
| <a name="input_tfe_tls_enforce"></a> [tfe\_tls\_enforce](#input\_tfe\_tls\_enforce) | Boolean to enforce TLS. | `bool` | `false` | no |
| <a name="input_tfe_user_data_template"></a> [tfe\_user\_data\_template](#input\_tfe\_user\_data\_template) | (optional) File name for user\_data\_template.sh.tpl file in `./templates folder` no path required | `string` | `"tfe_user_data.sh.tpl"` | no |
| <a name="input_tfe_vault_disable_mlock"></a> [tfe\_vault\_disable\_mlock](#input\_tfe\_vault\_disable\_mlock) | Boolean to disable mlock for internal Vault. | `bool` | `false` | no |
| <a name="input_verbose_template"></a> [verbose\_template](#input\_verbose\_template) | [Optional bool] Enables the user\_data template to be output in full for debug and review purposes. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_gcp_db_instance_ip"></a> [gcp\_db\_instance\_ip](#output\_gcp\_db\_instance\_ip) | Cloud SQL DB instance IP. |
| <a name="output_gcs_bucket_name"></a> [gcs\_bucket\_name](#output\_gcs\_bucket\_name) | Name of TFE gcs bucket. |
| <a name="output_google_sql_database_instance_id"></a> [google\_sql\_database\_instance\_id](#output\_google\_sql\_database\_instance\_id) | ID of Cloud SQL DB instance. |
| <a name="output_lb_ip_address"></a> [lb\_ip\_address](#output\_lb\_ip\_address) | IP Address of the Load Balancer. |
| <a name="output_tfe_fqdn"></a> [tfe\_fqdn](#output\_tfe\_fqdn) | `tfe_fqdn` input. |
| <a name="output_tfe_initial_user_url"></a> [tfe\_initial\_user\_url](#output\_tfe\_initial\_user\_url) | Terraform-Enterprise URL create initial admin user based on the `tfe_fqdn` input, and `tfe_iact_subnets` is set |
| <a name="output_tfe_retrieve_iact"></a> [tfe\_retrieve\_iact](#output\_tfe\_retrieve\_iact) | Terraform-Enterprise URL to retrieve initial user token based on `tfe_fqdn` input, and `tfe_iact_subnets` is set |
| <a name="output_url"></a> [url](#output\_url) | URL of TFE application based on `tfe_fqdn` input. |
| <a name="output_user_data_template"></a> [user\_data\_template](#output\_user\_data\_template) | n/a |
<!-- END_TF_DOCS -->
