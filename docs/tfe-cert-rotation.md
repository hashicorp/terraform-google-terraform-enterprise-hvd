# TFE Certificate Rotation

One of the required prerequisites to deploying this module is storing base64-encoded strings of your TFE TLS/SSL certificate and private key files in PEM format as secrets within GCP Secret Manager for bootstrapping automation purposes. The TFE metadata startup script is designed to retrieve the latest value of these secrets every time a new VM boots. Therefore, the process for updating TFE's TLS/SSL certificates is to update the values of the corresponding secrets in GCP Secrets Manager, and then to replace the running TFE GCE VM instance(s) within the Managed Instance Group (MIG) such that when the new instance(s) spawn and re-install TFE, they will retrieve and install the new certificates. See the section below for detailed steps.

## Secrets

| Certificate file type | Module input variable       |
|-----------------------|-----------------------------|
| TLS/SSL certificate   | `tfe_tls_cert_secret_id`    |
| TLS/SSL private key   | `tfe_tls_privkey_secret_id` |

## Procedure

Follow these steps to rotate the certificates for your TFE instance.

1. Obtain your new TFE TLS/SSL certificate file and private key file, both in PEM format.

2. Update the values of the existing secrets in GCP Secret Manager (`tfe_tls_cert_secret_id` and `tfe_tls_privkey_secret_id`, respectively). If you need assistance base64-encoding the PEM files into strings prior to updating the secret values in GCP, see the [prereqs reference](./prereqs.md#secrets-formatting).

3. During a maintenance window, connect to one of your existing TFE GCE VM instances and gracefully drain the node(s) from being able to execute any new Terraform runs.
   
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

4. Replace the running TFE GCE VM instance(s) within the managed instance group such that new instance(s) are created. This process will effectively re-install TFE on the new instance(s), including the retrieval and installation of the latest certificates from the GCP Secret Manager secrets.
