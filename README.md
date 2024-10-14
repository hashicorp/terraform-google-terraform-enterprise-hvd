# Terraform Enterprise HVD on GCP GCE

Terraform module aligned with HashiCorp Validated Designs (HVD) to deploy Terraform Enterprise (TFE) on Google Cloud Platform (GCP) using Compute Engine instances with a container runtime. This module defaults to deploying TFE in the `active-active` [operational mode](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/operation-modes), but `external` is also supported. Docker and Podman are the supported container runtimes.

![TFE on Google](https://raw.githubusercontent.com/hashicorp/terraform-google-terraform-enterprise-hvd/main/docs/images/architecture-logical-active-active.png)

## Prerequisites

### General

- TFE license file (_e.g._ `terraform.hclic`)
- Terraform CLI `>= 1.9` installed on clients/workstations that will be used to deploy TFE
- General understanding of how to use Terraform (Community Edition)
- General understanding of how to use GCP
- `git` CLI and Visual Studio Code editor installed on workstations are strongly recommended
- GCP projeect that TFE will be deployed in with permissions to provision these [resources](#resources) via Terraform CLI
- (Optional) GCP GCS bucket for [GCS remote state backend](https://developer.hashicorp.com/terraform/language/settings/backends/gcs) that will be used to manage the Terraform state file for this TFE deployment (out-of-band from the TFE application) via Terraform CLI (Community Edition)

### Networking

- GCP VPC network with the following:
  - VM subnet for TFE GCE instances to reside with Private Google Access enabled (refer to the [prereqs reference](./docs/prereqs.md#vm-subnet-with-private-google-access) for more details)
  - (Optional) Load balancer subnet (can be the same as VM subnet if desired; only used when `lb_is_internal` is `true`)
  - Private Service Access (PSA) configured in VPC network for service `servicenetworking.googleapis.com` (refer to the [prereqs reference](./docs/prereqs.md#private-service-access-psa) for more details)
- Chosen fully qualified domain name (FQDN) for your TFE instance (_e.g._ `tfe.gcp.example.com`)
- (Optional) Google Cloud DNS zone for optional TFE DNS record creation

#### Firewall rules

This module will automatically create the necessary firewall rules within the existing VPC network that you provide.

- Identify CIDR range(s) that will need to access the TFE application (managed via [cidr_allow_ingress_tfe_443](#input_cidr_allow_ingress_tfe_443) input variable)
- (Optional) Identity CIDR range(s) of monitoring tools that will need to access TFE metrics endpoint (managed via [cidr_allow_ingress_tfe_metrics](#input_cidr_allow_ingress_tfe_metrics) input variable)
- Be familiar with the [TFE ingress requirements](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#ingress)
- Be familiar with the [TFE egress requirements](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#egress)

### Secrets management

The following _bootstrap_ secrets stored in Google Secret Manager in order to boostrap the TFE deployment and installation:

- **TFE license file** - raw contents of license file (_e.g._ `cat terraform.hclic`)
- **TFE encryption password** - random characters (used to protect TFE's internally-managed Vault unseal key and root token)
- **TFE (PostgreSQL) database password** - random characters between 8 and 99 characters in length; must contain at least one uppercase letter, one lowercase letter, and one digit or special character
- **TFE TLS certificate** - certificate file in PEM format, base64-encoded into a string, and stored as a secret
- **TFE TLS certificate private key** - private key file in PEM format, base64-encoded into a string, and stored as a secret
- **TFE TLS CA bundle** - Ca bundle file in PEM format, base64-encoded into a string, and stored as a secret

Refer to the [prereqs reference](./docs/prereqs.md#tfe-bootstrap-secrets) for more details on how the secrets should be created and stored.

### Compute

One of the following mechanisms for shell access to TFE GCE VM instances:

- Ability to enable [IAP TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding#console) (enabled by default - managed via [allow_ingress_vm_ssh_from_iap](#input_allow_ingress_vm_ssh_from_iap))
-  GCE SSH key pair (use this if you do not want to SSH via IAP TCP forwarding)

### Log forwarding (optional)

One of the following logging destinations:

- Stackdriver (no action needed)
- A custom Fluent Bit configuration that will forward logs to your custom log destination

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

    >📝 Note: In this example, the user will have two separate TFE deployments; one for their `sandbox` environment, and one for their `production` environment. This is recommended, but not required.

4. (Optional) Uncomment and update the  [GCS remote state backend](https://developer.hashicorp.com/terraform/language/settings/backends/gcs) configuration provided in the `backend.tf` file with your own custom values. While this step is highly recommended, it is technically not required to use a remote backend config for your TFE deployment.

5. Populate your own custom values into the `terraform.tfvars.example` file that was provided (in particular, values enclosed in the `<>` characters). Then, remove the `.example` file extension such that the file is now named `terraform.tfvars`.

6. Navigate to the directory of your newly created Terraform configuration for your TFE deployment, and run `terraform init`, `terraform plan`, and `terraform apply`.

7. After your `terraform apply` finishes successfully, you can monitor the installation progress by connecting to your TFE gcp instance shell via SSH or GCP IAP and observing the meta data script(user_data) logs:<br>

   Higher-level logs:

   ```shell-session
   tail -f /var/log/tfe-cloud-init.log
   ```

   Lower-level logs:

   ```shell-session
   journalctl -xu google-startup-scripts -f
   ```

   >📝 Note: The `-f` argument is to follow the logs as they append in real-time, and is optional. You may remove the `-f` for a static view.

   The log files should display the following message after the startup script (_tfe_startup_script.sh_) finishes successfully:

   ```shell-session
   [INFO] - tfe_startup_script finished successfully!
   ```

8. After the startup script (_tfe_startup_script.sh_) finishes successfully, while still connected to the TFE GCE instance shell, you can check the health status of TFE:

   ```shell-session
   cd /etc/tfe
   sudo docker compose exec tfe tfe-health-check-status
   ```

9. Follow the steps [here](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/initial-admin-user) to create the TFE initial admin user.

---

## Docs

Below are links to various docs related to the customization and management of your TFE deployment:

- [Deployment Customizations](./docs/deployment-customizations.md)
- [Prereqs Reference](./docs/prereqs.md)
- [TFE TLS Certificate Rotation](./docs/tfe-cert-rotation.md)
- [TFE Configuration Settings](./docs/tfe-config-settings.md)
- [TFE Version Upgrades](./docs/tfe-version-upgrades.md)

---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 6.6 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 6.6 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~> 6.6 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | ~> 6.6 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.6 |

## Resources

| Name | Type |
|------|------|
| [google-beta_google_project_service_identity.gcp_project_cloud_sql_sa](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_project_service_identity) | resource |
| [google_compute_address.tfe_frontend_lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_firewall.vm_allow_ingress_ssh_from_cidr](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.vm_allow_ingress_ssh_from_iap](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.vm_allow_lb_health_checks_443](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.vm_allow_tfe_443](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.vm_allow_tfe_metrics_from_cidr](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.vm_tfe_self_allow](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_forwarding_rule.tfe_frontend_lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_health_check.tfe_auto_healing](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check) | resource |
| [google_compute_instance_template.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_region_backend_service.tfe_backend_lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_health_check.tfe_backend_lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_health_check) | resource |
| [google_compute_region_instance_group_manager.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager) | resource |
| [google_dns_record_set.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_kms_crypto_key_iam_member.gcp_project_gcs_sa_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_crypto_key_iam_member.postgres_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_project_iam_member.tfe_logging_stackdriver](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_redis_instance.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance) | resource |
| [google_secret_manager_secret_iam_member.tfe_ca_bundle](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_iam_member.tfe_cert](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_iam_member.tfe_encryption_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_iam_member.tfe_license](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_iam_member.tfe_privkey](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_service_account.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_key.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_key) | resource |
| [google_sql_database.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database) | resource |
| [google_sql_database_instance.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance) | resource |
| [google_sql_user.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) | resource |
| [google_storage_bucket.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.tfe_bucket_object_admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.tfe_bucket_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [random_id.gcs_bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_id.postgres_instance_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [google_client_config.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_compute_image.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_image) | data source |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_subnetwork.lb_subnet](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_subnetwork.vm_subnet](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_zones.up](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones) | data source |
| [google_dns_managed_zone.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/dns_managed_zone) | data source |
| [google_kms_crypto_key.gcs_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_crypto_key) | data source |
| [google_kms_crypto_key.postgres_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_crypto_key) | data source |
| [google_kms_key_ring.gcs_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_key_ring) | data source |
| [google_kms_key_ring.postgres_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_key_ring) | data source |
| [google_secret_manager_secret_version.tfe_database_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version) | data source |
| [google_storage_project_service_account.gcp_project_gcs_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_friendly_name_prefix"></a> [friendly\_name\_prefix](#input\_friendly\_name\_prefix) | Friendly name prefix used for uniquely naming all GCP resources for this deployment. Most commonly set to either an environment (e.g. 'sandbox', 'prod'), a team name, or a project name. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | ID of GCP project to deploy TFE in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | GCP region (location) to deploy TFE in. | `string` | n/a | yes |
| <a name="input_tfe_database_password_secret_id"></a> [tfe\_database\_password\_secret\_id](#input\_tfe\_database\_password\_secret\_id) | Name of PostgreSQL database password secret to retrieve from Google Secret Manager. | `string` | n/a | yes |
| <a name="input_tfe_encryption_password_secret_id"></a> [tfe\_encryption\_password\_secret\_id](#input\_tfe\_encryption\_password\_secret\_id) | Name of Google Secret Manager secret for TFE encryption password. | `string` | n/a | yes |
| <a name="input_tfe_fqdn"></a> [tfe\_fqdn](#input\_tfe\_fqdn) | Fully qualified domain name (FQDN) of TFE instance. This name should resolve to the TFE load balancer IP address and will be what users/clients use to access TFE. | `string` | n/a | yes |
| <a name="input_tfe_license_secret_id"></a> [tfe\_license\_secret\_id](#input\_tfe\_license\_secret\_id) | Name of Google Secret Manager secret for TFE license file. | `string` | n/a | yes |
| <a name="input_tfe_tls_ca_bundle_secret_id"></a> [tfe\_tls\_ca\_bundle\_secret\_id](#input\_tfe\_tls\_ca\_bundle\_secret\_id) | Name of Google Secret Manager secret for private/custom TLS Certificate Authority (CA) bundle in PEM format. Secret must be stored as a base64-encoded string. | `string` | n/a | yes |
| <a name="input_tfe_tls_cert_secret_id"></a> [tfe\_tls\_cert\_secret\_id](#input\_tfe\_tls\_cert\_secret\_id) | Name of Google Secret Manager secret for TFE TLS certificate in PEM format. Secret must be stored as a base64-encoded string. | `string` | n/a | yes |
| <a name="input_tfe_tls_privkey_secret_id"></a> [tfe\_tls\_privkey\_secret\_id](#input\_tfe\_tls\_privkey\_secret\_id) | Name of Google Secret Manager secret for TFE TLS private key in PEM format. Secret must be stored as a base64-encoded string. | `string` | n/a | yes |
| <a name="input_vm_subnet_name"></a> [vm\_subnet\_name](#input\_vm\_subnet\_name) | Name of VPC subnet to deploy TFE GCE VM instances in. | `string` | n/a | yes |
| <a name="input_vpc_network_name"></a> [vpc\_network\_name](#input\_vpc\_network\_name) | Name of VPC network to deploy TFE in. | `string` | n/a | yes |
| <a name="input_allow_ingress_vm_ssh_from_iap"></a> [allow\_ingress\_vm\_ssh\_from\_iap](#input\_allow\_ingress\_vm\_ssh\_from\_iap) | Boolean to create firewall rule to allow TCP/22 (SSH) inbound to TFE GCE instances from Google Cloud IAP CIDR block. | `bool` | `true` | no |
| <a name="input_cidr_allow_ingress_tfe_443"></a> [cidr\_allow\_ingress\_tfe\_443](#input\_cidr\_allow\_ingress\_tfe\_443) | List of CIDR ranges to allow TCP/443 (HTTPS) inbound to TFE load balancer. | `list(string)` | `null` | no |
| <a name="input_cidr_allow_ingress_tfe_metrics"></a> [cidr\_allow\_ingress\_tfe\_metrics](#input\_cidr\_allow\_ingress\_tfe\_metrics) | List of CIDR ranges to allow TCP/9090 (HTTP) and TCP/9091 (HTTPS) inbound to TFE metrics collection endpoint. | `list(string)` | `null` | no |
| <a name="input_cidr_allow_ingress_vm_ssh"></a> [cidr\_allow\_ingress\_vm\_ssh](#input\_cidr\_allow\_ingress\_vm\_ssh) | List of CIDR ranges to allow TCP/22 (SSH) inbound to TFE GCE instances. | `list(string)` | `null` | no |
| <a name="input_cloud_dns_managed_zone_name"></a> [cloud\_dns\_managed\_zone\_name](#input\_cloud\_dns\_managed\_zone\_name) | Name of Google Cloud DNS managed zone to create TFE DNS record in. Required when `create_tfe_cloud_dns_record` is `true`. | `string` | `null` | no |
| <a name="input_common_labels"></a> [common\_labels](#input\_common\_labels) | Map of common labels to apply to all GCP resources. | `map(string)` | `{}` | no |
| <a name="input_container_runtime"></a> [container\_runtime](#input\_container\_runtime) | Container runtime to use for TFE deployment. Supported values are `docker` or `podman`. | `string` | `"docker"` | no |
| <a name="input_create_tfe_cloud_dns_record"></a> [create\_tfe\_cloud\_dns\_record](#input\_create\_tfe\_cloud\_dns\_record) | Boolean to create Google Cloud DNS record for TFE using the value of `tfe_fqdn` as the record name, resolving to the load balancer IP. `cloud_dns_managed_zone_name` is required when `true`. | `bool` | `false` | no |
| <a name="input_custom_fluent_bit_config"></a> [custom\_fluent\_bit\_config](#input\_custom\_fluent\_bit\_config) | Custom Fluent Bit configuration for log forwarding. Only valid when `tfe_log_forwarding_enabled` is `true` and `log_fwd_destination_type` is `custom`. | `string` | `null` | no |
| <a name="input_custom_tfe_startup_script_template"></a> [custom\_tfe\_startup\_script\_template](#input\_custom\_tfe\_startup\_script\_template) | Name of custom TFE startup script template file. File must exist within a directory named `./templates` within your current working directory. | `string` | `null` | no |
| <a name="input_docker_version"></a> [docker\_version](#input\_docker\_version) | Version of Docker to install on TFE GCE VM instances. | `string` | `"26.1.4-1"` | no |
| <a name="input_gce_disk_size_gb"></a> [gce\_disk\_size\_gb](#input\_gce\_disk\_size\_gb) | Size in gigabytes of root disk of TFE GCE VM instances. | `number` | `50` | no |
| <a name="input_gce_image_name"></a> [gce\_image\_name](#input\_gce\_image\_name) | VM image for TFE GCE instances. | `string` | `"ubuntu-pro-2404-noble-amd64-v20241004"` | no |
| <a name="input_gce_image_project"></a> [gce\_image\_project](#input\_gce\_image\_project) | ID of project in which the TFE GCE VM image belongs. | `string` | `"ubuntu-os-cloud"` | no |
| <a name="input_gce_machine_type"></a> [gce\_machine\_type](#input\_gce\_machine\_type) | Machine type (size) of TFE GCE VM instances. | `string` | `"n2-standard-4"` | no |
| <a name="input_gce_ssh_public_key"></a> [gce\_ssh\_public\_key](#input\_gce\_ssh\_public\_key) | SSH public key to add to TFE GCE VM instances for SSH access. Generally not needed if using Google IAP for SSH. | `string` | `null` | no |
| <a name="input_gcs_force_destroy"></a> [gcs\_force\_destroy](#input\_gcs\_force\_destroy) | Boolean indicating whether to allow force destroying the TFE GCS bucket. GCS bucket can be destroyed if it is not empty when `true`. | `bool` | `false` | no |
| <a name="input_gcs_kms_cmek_name"></a> [gcs\_kms\_cmek\_name](#input\_gcs\_kms\_cmek\_name) | Name of Cloud KMS customer managed encryption key (CMEK) to use for TFE GCS bucket encryption. | `string` | `null` | no |
| <a name="input_gcs_kms_keyring_name"></a> [gcs\_kms\_keyring\_name](#input\_gcs\_kms\_keyring\_name) | Name of Cloud KMS key ring that contains KMS customer managed encryption key (CMEK) to use for TFE GCS bucket encryption. Geographic location (region) of the key ring must match the location of the TFE GCS bucket. | `string` | `null` | no |
| <a name="input_gcs_location"></a> [gcs\_location](#input\_gcs\_location) | Location of TFE GCS bucket to create. | `string` | `"US"` | no |
| <a name="input_gcs_storage_class"></a> [gcs\_storage\_class](#input\_gcs\_storage\_class) | Storage class of TFE GCS bucket. | `string` | `"MULTI_REGIONAL"` | no |
| <a name="input_gcs_uniform_bucket_level_access"></a> [gcs\_uniform\_bucket\_level\_access](#input\_gcs\_uniform\_bucket\_level\_access) | Boolean to enable uniform bucket level access on TFE GCS bucket. | `bool` | `true` | no |
| <a name="input_gcs_versioning_enabled"></a> [gcs\_versioning\_enabled](#input\_gcs\_versioning\_enabled) | Boolean to enable versioning on TFE GCS bucket. | `bool` | `true` | no |
| <a name="input_is_secondary_region"></a> [is\_secondary\_region](#input\_is\_secondary\_region) | Boolean indicating whether this TFE deployment is in your primary region or secondary (disaster recovery) region. | `bool` | `false` | no |
| <a name="input_lb_is_internal"></a> [lb\_is\_internal](#input\_lb\_is\_internal) | Boolean to create an internal GCP load balancer for TFE. | `bool` | `true` | no |
| <a name="input_lb_static_ip_address"></a> [lb\_static\_ip\_address](#input\_lb\_static\_ip\_address) | Static IP address to assign to TFE load balancer forwarding rule (front end) when `lb_is_internal` is `true`. Must be a valid IP address within `vm_subnet_name`. If not set, an available IP address will automatically be selected. | `string` | `null` | no |
| <a name="input_lb_subnet_name"></a> [lb\_subnet\_name](#input\_lb\_subnet\_name) | Name of VPC subnet to deploy TFE load balancer in. This can be the same subnet as the VM subnet if you do not wish to provide a separate subnet for the load balancer. Only applicable when `lb_is_internal` is `true`. Must be `null` when `lb_is_internal` is `false`. | `string` | `null` | no |
| <a name="input_log_fwd_destination_type"></a> [log\_fwd\_destination\_type](#input\_log\_fwd\_destination\_type) | Type of log forwarding destination for Fluent Bit. Valid values are `stackdriver` or `custom`. | `string` | `"stackdriver"` | no |
| <a name="input_mig_initial_delay_sec"></a> [mig\_initial\_delay\_sec](#input\_mig\_initial\_delay\_sec) | Number of seconds for managed instance group to wait before applying autohealing policies to new GCE instances in managed instance group. | `number` | `900` | no |
| <a name="input_mig_instance_count"></a> [mig\_instance\_count](#input\_mig\_instance\_count) | Desired number of TFE GCE instances to run in managed instance group. Must be `1` when `tfe_operational_mode` is `external`. | `number` | `1` | no |
| <a name="input_postgres_availability_type"></a> [postgres\_availability\_type](#input\_postgres\_availability\_type) | Availability type of Cloud SQL for PostgreSQL instance. | `string` | `"REGIONAL"` | no |
| <a name="input_postgres_backup_start_time"></a> [postgres\_backup\_start\_time](#input\_postgres\_backup\_start\_time) | HH:MM time format indicating when daily automatic backups of Cloud SQL for PostgreSQL should run. Defaults to 12 AM (midnight) UTC. | `string` | `"00:00"` | no |
| <a name="input_postgres_deletetion_protection"></a> [postgres\_deletetion\_protection](#input\_postgres\_deletetion\_protection) | Boolean to enable deletion protection for Cloud SQL for PostgreSQL instance. | `bool` | `false` | no |
| <a name="input_postgres_disk_size"></a> [postgres\_disk\_size](#input\_postgres\_disk\_size) | Size in GB of PostgreSQL disk. | `number` | `50` | no |
| <a name="input_postgres_insights_config"></a> [postgres\_insights\_config](#input\_postgres\_insights\_config) | Configuration settings for Cloud SQL for PostgreSQL insights. | <pre>object({<br>    query_insights_enabled  = bool<br>    query_plans_per_minute  = number<br>    query_string_length     = number<br>    record_application_tags = bool<br>    record_client_address   = bool<br>  })</pre> | <pre>{<br>  "query_insights_enabled": false,<br>  "query_plans_per_minute": 5,<br>  "query_string_length": 1024,<br>  "record_application_tags": false,<br>  "record_client_address": false<br>}</pre> | no |
| <a name="input_postgres_kms_cmek_name"></a> [postgres\_kms\_cmek\_name](#input\_postgres\_kms\_cmek\_name) | Name of Cloud KMS customer managed encryption key (CMEK) to use for Cloud SQL for PostgreSQL database instance. | `string` | `null` | no |
| <a name="input_postgres_kms_keyring_name"></a> [postgres\_kms\_keyring\_name](#input\_postgres\_kms\_keyring\_name) | Name of Cloud KMS Key Ring that contains KMS key to use for Cloud SQL for PostgreSQL. Geographic location (region) of key ring must match the location of the TFE Cloud SQL for PostgreSQL database instance. | `string` | `null` | no |
| <a name="input_postgres_machine_type"></a> [postgres\_machine\_type](#input\_postgres\_machine\_type) | Machine size of Cloud SQL for PostgreSQL instance. | `string` | `"db-custom-4-16384"` | no |
| <a name="input_postgres_maintenance_window"></a> [postgres\_maintenance\_window](#input\_postgres\_maintenance\_window) | Optional maintenance window settings for the Cloud SQL for PostgreSQL instance. | <pre>object({<br>    day          = number<br>    hour         = number<br>    update_track = string<br>  })</pre> | <pre>{<br>  "day": 7,<br>  "hour": 0,<br>  "update_track": "stable"<br>}</pre> | no |
| <a name="input_postgres_ssl_mode"></a> [postgres\_ssl\_mode](#input\_postgres\_ssl\_mode) | Indicates whether to enforce TLS/SSL connections to the Cloud SQL for PostgreSQL instance. | `string` | `"ENCRYPTED_ONLY"` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL version to use. | `string` | `"POSTGRES_16"` | no |
| <a name="input_redis_auth_enabled"></a> [redis\_auth\_enabled](#input\_redis\_auth\_enabled) | Boolean to enable authentication on Redis instance. | `bool` | `true` | no |
| <a name="input_redis_connect_mode"></a> [redis\_connect\_mode](#input\_redis\_connect\_mode) | Network connection mode for Redis instance. | `string` | `"PRIVATE_SERVICE_ACCESS"` | no |
| <a name="input_redis_kms_cmek_name"></a> [redis\_kms\_cmek\_name](#input\_redis\_kms\_cmek\_name) | Name of Cloud KMS customer managed encryption key (CMEK) to use for TFE Redis instance. | `string` | `null` | no |
| <a name="input_redis_kms_keyring_name"></a> [redis\_kms\_keyring\_name](#input\_redis\_kms\_keyring\_name) | Name of Cloud KMS key ring that contains KMS customer managed encryption key (CMEK) to use for TFE Redis instance. Geographic location (region) of key ring must match the location of the TFE Redis instance. | `string` | `null` | no |
| <a name="input_redis_memory_size_gb"></a> [redis\_memory\_size\_gb](#input\_redis\_memory\_size\_gb) | The size of the Redis instance in GiB. | `number` | `6` | no |
| <a name="input_redis_tier"></a> [redis\_tier](#input\_redis\_tier) | The service tier of the Redis instance. Set to `STANDARD_HA` for high availability. | `string` | `"STANDARD_HA"` | no |
| <a name="input_redis_transit_encryption_mode"></a> [redis\_transit\_encryption\_mode](#input\_redis\_transit\_encryption\_mode) | Determines transit encryption (TLS) mode for Redis instance. | `string` | `"DISABLED"` | no |
| <a name="input_redis_version"></a> [redis\_version](#input\_redis\_version) | The version of Redis software. | `string` | `"REDIS_7_2"` | no |
| <a name="input_tfe_capacity_concurrency"></a> [tfe\_capacity\_concurrency](#input\_tfe\_capacity\_concurrency) | Maximum number of concurrent Terraform runs to allow on a TFE node. | `number` | `10` | no |
| <a name="input_tfe_capacity_cpu"></a> [tfe\_capacity\_cpu](#input\_tfe\_capacity\_cpu) | Maxium number of CPU cores that a Terraform run is allowed to consume on a TFE node. Defaults to `0` which is no limit. | `number` | `0` | no |
| <a name="input_tfe_capacity_memory"></a> [tfe\_capacity\_memory](#input\_tfe\_capacity\_memory) | Maximum amount of memory (in MiB) that a Terraform run is allowed to consume on a TFE node. | `number` | `2048` | no |
| <a name="input_tfe_database_name"></a> [tfe\_database\_name](#input\_tfe\_database\_name) | Name of TFE PostgreSQL database to create. | `string` | `"tfe"` | no |
| <a name="input_tfe_database_parameters"></a> [tfe\_database\_parameters](#input\_tfe\_database\_parameters) | Additional parameters to pass into the TFE database settings for the PostgreSQL connection URI. | `string` | `"sslmode=require"` | no |
| <a name="input_tfe_database_reconnect_enabled"></a> [tfe\_database\_reconnect\_enabled](#input\_tfe\_database\_reconnect\_enabled) | Boolean to enable database reconnection in the event of a TFE PostgreSQL database cluster failover. | `bool` | `true` | no |
| <a name="input_tfe_database_user"></a> [tfe\_database\_user](#input\_tfe\_database\_user) | Name of TFE PostgreSQL database user to create. | `string` | `"tfe"` | no |
| <a name="input_tfe_hairpin_addressing"></a> [tfe\_hairpin\_addressing](#input\_tfe\_hairpin\_addressing) | Boolean to enable hairpin addressing within TFE container networking for loopback prevention with a layer 4 internal load balancer. | `bool` | `true` | no |
| <a name="input_tfe_http_port"></a> [tfe\_http\_port](#input\_tfe\_http\_port) | HTTP port for TFE application containers to listen on. | `number` | `8080` | no |
| <a name="input_tfe_https_port"></a> [tfe\_https\_port](#input\_tfe\_https\_port) | HTTPS port for TFE application containers to listen on. | `number` | `8443` | no |
| <a name="input_tfe_iact_subnets"></a> [tfe\_iact\_subnets](#input\_tfe\_iact\_subnets) | Comma-separated list of subnets in CIDR notation that are allowed to retrieve the TFE initial admin creation token via the API or web browser. | `string` | `null` | no |
| <a name="input_tfe_iact_time_limit"></a> [tfe\_iact\_time\_limit](#input\_tfe\_iact\_time\_limit) | Number of minutes that the TFE initial admin creation token can be retrieved via the API after the application starts. | `number` | `60` | no |
| <a name="input_tfe_iact_trusted_proxies"></a> [tfe\_iact\_trusted\_proxies](#input\_tfe\_iact\_trusted\_proxies) | Comma-separated list of proxy IP addresses that are allowed to retrieve the TFE initial admin creation token via the API or web browser. | `string` | `null` | no |
| <a name="input_tfe_image_name"></a> [tfe\_image\_name](#input\_tfe\_image\_name) | Name of the TFE container image. Only set this away from the default if you are hosting the TFE container image in your own custom registry. | `string` | `"hashicorp/terraform-enterprise"` | no |
| <a name="input_tfe_image_repository_password"></a> [tfe\_image\_repository\_password](#input\_tfe\_image\_repository\_password) | Pasword for container registry where TFE container image is hosted. Leave as `null` if using the default TFE registry, as the default password is your TFE license file. | `string` | `null` | no |
| <a name="input_tfe_image_repository_url"></a> [tfe\_image\_repository\_url](#input\_tfe\_image\_repository\_url) | URL of container registry where the TFE container image is hosted. Only set this away from the default if you are hosting the TFE container image in your own custom registry. | `string` | `"images.releases.hashicorp.com"` | no |
| <a name="input_tfe_image_repository_username"></a> [tfe\_image\_repository\_username](#input\_tfe\_image\_repository\_username) | Username for container registry where TFE container image is hosted. | `string` | `"terraform"` | no |
| <a name="input_tfe_image_tag"></a> [tfe\_image\_tag](#input\_tfe\_image\_tag) | Tag (release) for the TFE container image. This represents which version (release) of TFE to deploy. | `string` | `"v202409-3"` | no |
| <a name="input_tfe_license_reporting_opt_out"></a> [tfe\_license\_reporting\_opt\_out](#input\_tfe\_license\_reporting\_opt\_out) | Boolean to opt out of TFE license reporting. | `bool` | `false` | no |
| <a name="input_tfe_log_forwarding_enabled"></a> [tfe\_log\_forwarding\_enabled](#input\_tfe\_log\_forwarding\_enabled) | Boolean to enable TFE log forwarding configuration via Fluent Bit. | `bool` | `false` | no |
| <a name="input_tfe_metrics_enable"></a> [tfe\_metrics\_enable](#input\_tfe\_metrics\_enable) | Boolean to enable TFE metrics collection endpoints. | `bool` | `false` | no |
| <a name="input_tfe_metrics_http_port"></a> [tfe\_metrics\_http\_port](#input\_tfe\_metrics\_http\_port) | HTTP port for TFE metrics collection endpoint to listen on. | `number` | `9090` | no |
| <a name="input_tfe_metrics_https_port"></a> [tfe\_metrics\_https\_port](#input\_tfe\_metrics\_https\_port) | HTTPS port for TFE metrics collection endpoint to listen on. | `number` | `9091` | no |
| <a name="input_tfe_operational_mode"></a> [tfe\_operational\_mode](#input\_tfe\_operational\_mode) | [Operational mode](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/operation-modes) for TFE. Valid values are `active-active` or `external`. | `string` | `"active-active"` | no |
| <a name="input_tfe_run_pipeline_docker_network"></a> [tfe\_run\_pipeline\_docker\_network](#input\_tfe\_run\_pipeline\_docker\_network) | Name of Docker network where the containers that execute Terraform runs (agents) will be created. The network must already exist, it will not be created automatically. Leave as `null` to use the default network created during the TFE installation. | `string` | `null` | no |
| <a name="input_tfe_run_pipeline_image"></a> [tfe\_run\_pipeline\_image](#input\_tfe\_run\_pipeline\_image) | Name of container image used to execute Terraform runs on a TFE node. Leave as `null` to use the default agent that ships with TFE. | `string` | `null` | no |
| <a name="input_tfe_tls_enforce"></a> [tfe\_tls\_enforce](#input\_tfe\_tls\_enforce) | Boolean to enforce TLS, Strict-Transport-Security headers, and secure cookies within TFE. | `bool` | `false` | no |
| <a name="input_tfe_usage_reporting_opt_out"></a> [tfe\_usage\_reporting\_opt\_out](#input\_tfe\_usage\_reporting\_opt\_out) | Boolean to opt out of TFE usage reporting. | `bool` | `false` | no |
| <a name="input_tfe_vault_disable_mlock"></a> [tfe\_vault\_disable\_mlock](#input\_tfe\_vault\_disable\_mlock) | Boolean to disable mlock for internal (embedded) Vault within TFE. | `bool` | `false` | no |
| <a name="input_vpc_network_project_id"></a> [vpc\_network\_project\_id](#input\_vpc\_network\_project\_id) | ID of GCP project where the existing VPC network resides, if it is different than the `project_id` where TFE will be deployed. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_tfe_create_initial_admin_user_url"></a> [tfe\_create\_initial\_admin\_user\_url](#output\_tfe\_create\_initial\_admin\_user\_url) | URL to create TFE initial admin user. |
| <a name="output_tfe_database_host"></a> [tfe\_database\_host](#output\_tfe\_database\_host) | Private IP address and port of TFE Cloud SQL for PostgreSQL database instance. |
| <a name="output_tfe_database_instance_id"></a> [tfe\_database\_instance\_id](#output\_tfe\_database\_instance\_id) | ID of TFE Cloud SQL for PostgreSQL database instance. |
| <a name="output_tfe_database_name"></a> [tfe\_database\_name](#output\_tfe\_database\_name) | Name of TFE database. |
| <a name="output_tfe_database_password"></a> [tfe\_database\_password](#output\_tfe\_database\_password) | Password of TFE database user. |
| <a name="output_tfe_database_user"></a> [tfe\_database\_user](#output\_tfe\_database\_user) | Username of TFE database. |
| <a name="output_tfe_gcs_bucket_location"></a> [tfe\_gcs\_bucket\_location](#output\_tfe\_gcs\_bucket\_location) | Location of TFE GCS bucket. |
| <a name="output_tfe_lb_ip_address"></a> [tfe\_lb\_ip\_address](#output\_tfe\_lb\_ip\_address) | IP Address of TFE front end load balancer (forwarding rule). |
| <a name="output_tfe_load_balancing_scheme"></a> [tfe\_load\_balancing\_scheme](#output\_tfe\_load\_balancing\_scheme) | Load balancing scheme of TFE front end load balancer (forwarding rule). |
| <a name="output_tfe_object_storage_google_bucket"></a> [tfe\_object\_storage\_google\_bucket](#output\_tfe\_object\_storage\_google\_bucket) | Name of TFE GCS bucket. |
| <a name="output_tfe_redis_host"></a> [tfe\_redis\_host](#output\_tfe\_redis\_host) | Hostname/IP address (and port if non-default) of TFE Redis instance. |
| <a name="output_tfe_redis_password"></a> [tfe\_redis\_password](#output\_tfe\_redis\_password) | Password of TFE Redis instance. |
| <a name="output_tfe_redis_use_auth"></a> [tfe\_redis\_use\_auth](#output\_tfe\_redis\_use\_auth) | Whether TFE Redis instance uses authentication. |
| <a name="output_tfe_redis_use_tls"></a> [tfe\_redis\_use\_tls](#output\_tfe\_redis\_use\_tls) | Whether |
| <a name="output_tfe_redis_user"></a> [tfe\_redis\_user](#output\_tfe\_redis\_user) | Username of TFE Redis instance. |
| <a name="output_tfe_retrieve_iact_url"></a> [tfe\_retrieve\_iact\_url](#output\_tfe\_retrieve\_iact\_url) | URL to retrieve TFE initial admin creation token. |
| <a name="output_tfe_url"></a> [tfe\_url](#output\_tfe\_url) | URL of TFE application based on `tfe_fqdn` input value. |
<!-- END_TF_DOCS -->
