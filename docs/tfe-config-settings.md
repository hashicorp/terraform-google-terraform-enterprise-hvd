# TFE Configuration Settings

There are various configuration settings that can be applied when deploying or managing your TFE instance. For a comprehensive list of available settings and their descriptions, refer to the [Terraform Enterprise configuration reference](https://developer.hashicorp.com/terraform/enterprise/deploy/reference/configuration) documentation. This will be referred to as the _configuration reference_ throughout this document.

This module provides input variables that correspond to _most of_ the available, applicable settings from the configuration reference. Almost all of these input variables have default values, so they are not included as inputs within the module blocks of the Terraform configurations in the [example scenarios](../examples/).

## Manage Your TFE Settings

To include a setting from the configuration reference in your TFE deployment, follow these steps:

1. Identify the desired setting from the [Terraform Enterprise configuration reference](https://developer.hashicorp.com/terraform/enterprise/deploy/reference/configuration).
2. Locate the corresponding input variable in the `variables.tf` file.
3. Review the default variable value to determine if it meets your requirements.
4. If the module default value is not sufficient, add the input variable to the module block managing your TFE deployment.
5. Apply the change via Terraform.

### Example exercise

Let's say you want to set the maximum number of Terraform runs allowed on your TFE node. Here are your steps:

1. You identified this setting exists on the [Terraform Enterprise configuration reference](https://developer.hashicorp.com/terraform/enterprise/deploy/reference/configuration) under the name `TFE_CAPACITY_CONCURRENCY`.

2. You found the corresponding input variable exists in `variables.tf`, named `tfe_capacity_currency`.

3. You identified the default value of `tfe_capacity_currency` within `variables.tf` is set to `10`, but you want to increase it to `15`.

4. You updated your Terraform configuration managing your TFE deployment accordingly:

   **main.tf**:

   ```hcl
   module "tfe" {
     ...
     tfe_capacity_currency = var.tfe_capacity_concurrency
     ...
   }
   ```

   **terraform.tfvars**:

   ```hcl
   ...
   tfe_capacity_currency = 15
   ...
   ```

5. During a maintenance window, you ran `terraform apply` to apply the changes.

### Missing configuration settings

Some settings from the configuration reference are intentionally not exposed as input variables to this module for the following reasons:

1. The value of the setting is automatically derived by the module from other configurations or resources that are created.
2. The setting is hard coded based on the module's design and is not intended to be configurable by users.

If you feel like a setting from the configuration reference is missing from the `variables.tf` of this module, then please file a GitHub issue.

## Health and admin endpoints

Terraform Enterprise 1.2.0 introduced the readiness endpoint and 1.2.1 fixed the `200 OK` behavior required for load balancer integrations. This module therefore switches health checks to `/api/v1/health/readiness` for semver tags `1.2.1` and later, while preserving `/_health_check` for older calver releases.

The module also exposes `tfe_admin_https_port` and `tfe_admin_console_disabled` so you can control the system admin endpoint separately from the main application port. If you enable the admin console, also set `cidr_allow_ingress_tfe_admin_console` to restrict access.

## Secondary hostname settings

TFE supports a secondary hostname for callback-driven integrations. This module exposes the core settings required for that workflow:

- `tfe_hostname_secondary` -> `TFE_HOSTNAME_SECONDARY`
- `tfe_oidc_hostname_choice` -> `TFE_OIDC_HOSTNAME_CHOICE`
- `tfe_vcs_hostname_choice` -> `TFE_VCS_HOSTNAME_CHOICE`
- `tfe_run_task_hostname_choice` -> `TFE_RUN_TASK_HOSTNAME_CHOICE`

When `tfe_hostname_secondary` is set, the startup script also retrieves the secondary certificate, key, and CA bundle secrets and maps them to:

- `TFE_TLS_CERT_FILE_SECONDARY`
- `TFE_TLS_KEY_FILE_SECONDARY`
- `TFE_TLS_CA_BUNDLE_FILE_SECONDARY`

If `tfe_hairpin_addressing` is enabled, the module adds both the primary and secondary hostnames to the runtime extra-host mappings so run-pipeline traffic can resolve either hostname back to the local VM.
