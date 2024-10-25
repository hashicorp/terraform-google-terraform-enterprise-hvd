# TFE Configuration Settings

There are various configuration settings that can be applied when deploying or managing your TFE instance. For a comprehensive list of available settings and their descriptions, refer to the [Terraform Enterprise configuration reference](https://developer.hashicorp.com/terraform/enterprise/deploy/reference/configuration) documentation. This will be referred to as the _configuration reference_ throughout this document.

This module provides input variables that correspond to _most of_ the available, applicable settings from the configuration reference. Almost all of these input variables have default values, so they are not included as inputs within the module blocks of the Terraform configurations in the [example scenarios](https://github.com/hashicorp/terraform-google-terraform-enterprise-hvd/blob/0.2.0/examples/).

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
