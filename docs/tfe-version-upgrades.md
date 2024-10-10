# TFE Version Upgrades

TFE follows a monthly release cadence. See the [Terraform Enterprise Releases](https://developer.hashicorp.com/terraform/enterprise/releases) page for full details on the releases. Since we have fully automated the deployment/installation of TFE, and the TFE application data is decoupled from the compute (GCE) layer; the GCE VM instance(s) are stateless, ephemeral, and are treated as immutable. Therefore, upgrading your TFE instance to a new version involves updating the Terraform configuration managing your TFE deployment to reflect the new (target) version. Once the change is applied via Terraform, this will update the TFE GCE instance template and managed instance group (MIG), triggering the replacement of the existing running TFE GCE VM instances with new ones, where the target version of TFE will be installed on the newly created instances.

This module includes an input variable named `tfe_image_tag` that dictates which version of TFE is deployed.

## Procedure

1. Determine your desired version of TFE from the [Terraform Enterprise Releases](https://developer.hashicorp.com/terraform/enterprise/releases) documentation page. The value that you need will be in the **Version** column of the table that is displayed. Ensure you are on the correct tab of the table based on the container runtime you have chosen for your deployment (Docker or Podman). When determing your target TFE version to upgrade to, be sure to check if there are any required releases to upgrade to first in between your current and target version (denoted by a `*` character in the table).

2. During a maintenance window, connect to one of your existing TFE GCE VM instances and gracefully drain the node(s) from being able to execute any new Terraform runs.
   
   Access the TFE command line (`tfectl`) with Docker:

   ```shell-session
   sudo docker exec -it <tfe-container-name> bash
   ```

   Access the TFE command line (`tfectl`) with Podman:

   ```shell-session
   sudo podman exec -it <tfe-container-name> bash
   ```

   Gracefully stop work on all nodes:

   ```shell-session
   tfectl node drain --all
   ```

   For more details on the above commands, see the following documentation:

    - [Access the TFE Command Line](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/admin/admin-cli/cli-access)
    - [Gracefully Stop Work on a Node](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/admin/admin-cli/admin-cli#gracefully-stop-work-on-a-node)

3. Update the value of the `tfe_image_tag` input variable within your `terraform.tfvars` file to your target TFE version.

   ```hcl
   tfe_image_tag = "v202410-1"
   ```

4. From the directory managing your TFE deployment, run `terraform apply` to update the TFE GCE instance template with the new target `tfe_image_tag` version. This will trigger the managed instance group to replace the existing running TFE GCE VM instance(s) with new ones, on which the target version of TFE will be installed.