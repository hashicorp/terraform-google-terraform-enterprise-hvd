# TFE Version Upgrades

TFE follows a monthly release cadence. See the [Terraform Enterprise Releases](https://developer.hashicorp.com/terraform/enterprise/releases) page for full details on the releases. Since we have bootstrapped and automated the TFE deployment and the TFE application data is decoupled from the compute (GCE) layer, the GCE instance(s) are stateless, ephemeral, and are treated as immutable. Therefore, the process of upgrading your TFE instance to a new version involves updating your Terraform code managing your TFE deployment to reflect the new version, applying the change via Terraform to update the TFE GCE Instance Template, and then replacing running GCE instance(s) within the Autoscaling Group.

This module includes an input variable named `tfe_image_tag` that dictates which version of TFE is deployed.

## Procedure

 Here are the steps to follow:

1. Determine your desired version of TFE from the [Terraform Enterprise Releases](https://developer.hashicorp.com/terraform/enterprise/releases) page. The value that you need will be in the **Version** column of the table that is displayed. review the documentation found at <https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/admin/upgrade>.

2. Out of precaution, generate a backup of your RDS/PostgreSQL database.

3. Update the value of the `tfe_image_tag` input variable within your `terraform.tfvars` file.

```hcl
  tfe_image_tag = "v202405-1"
```

4. From within the directory managing your TFE deployment, run `terraform apply` to update the TFE GCE Instance Template.

5. During a maintenance window, terminate the running TFE GCE instance(s) which will trigger the Autoscaling Group to spawn new instance(s) from the latest version of the TFE GCE Instance Template. This process will effectively re-install TFE on the new instance(s), including the updated `tfe_image_tag` value.
