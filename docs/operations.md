# TFE Operations

<!-- TOD: update for FDO -->

This page contains information on operational tasks & procedures that TFE admins/operators might be responsible for.

## Upgrades
The upgrading of TFE application versions should be done via Terraform if TFE was deployed via this module.
The procedure will slightly vary based on if the installation method was _online_ or _airgap_.

### Online
1. Visit the [TFE Releases](https://www.terraform.io/docs/enterprise/release/index.html) page to obtain the _Release Sequence_ number for the desired version to upgrade to.

> For more detail on the release, see the [TFE Release Notes repository](https://github.com/hashicorp/terraform-enterprise-release-notes)

2. As a precautionary measure, backup the AWS RDS PostgreSQL database via the AWS console or other preferred method.

3. Within the Terraform configuration that was used to deploy TFE, modify the value of the input variable `tfe_release_sequence` to the desired version (_i.e._ `568`).

4. `terraform apply` the change from step 3. This should only update the AWS Launch Template and not impact the running instance(s) in the Autoscaling Group.

5. During a maintenance window, replace the running instance(s) in the Autoscaling Group such that the subsequent instance(s) will be built from the latest Launch Template version.

6. After about 10-15 minutes, attempt to log into the TFE application as normal.

7. Validate the TFE application by executing at least one Terraform Run on a Workspace.

### Airgap
1. Visit the TFE airgap bundle download page and enter your password (URL should start with https://get.replicated.com/airgap/#/terraformenterprise/*). Download the bundle for the desired version.

2. [Optional] change the name of the airgap bundle file to make it easier to read and reference (_i.e._ `tfe-568.airgap`).

3. Upload the airgap bundle file to the S3 "bootstrap" bucket.

4. As a precautionary measure, backup the AWS RDS PostgreSQL database via the AWS console or other preferred method.

5. Within the Terraform configuration that was used to deploy TFE, modify the value of the input variable `tfe_airgap_bundle_path` to reflect the S3 filepath of the new airgap bundle (_i.e._ `s3://tfe-bootstrap-bucket/tfe-568.airgap`).

6. `terraform apply` the change from step 5. This should only update the AWS Launch Template and not impact the running instance(s) in the Autoscaling Group.

7. Follow steps 5-7 from the previous section to complete the upgrade.







