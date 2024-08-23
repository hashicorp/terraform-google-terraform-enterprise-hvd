# TFE Certificate Rotation

One of the required prerequisites to deploying this module is storing base64-encoded strings of your TFE TLS/SSL certificate and private key files in PEM format as plaintext secrets within GCP Secrets Manager for bootstrapping automation purposes. The TFE GCP metadata script is designed to retrieve the latest value of these secrets every time it runs. Therefore, the process for updating TFE's TLS/SSL certificates are to update the values of the corresponding secrets in GCP Secrets Manager, and then to replace the running gce instance(s) within the Instance Group such that when the new instance(s) spawn and re-install TFE, they pick up the new certs. See the section below for detailed steps.


## Secrets
| Certificate file    | Module input variable        |
|---------------------|------------------------------|
| TLS/SSL certificate | `tfe_tls_cert_secret_arn`    |
| TLS/SSL private key | `tfe_tls_privkey_secret_arn` |


## Procedure
Follow these steps to rotate the certificates for your TFE instance.

1. Obtain your new TFE TLS/SSL certificate file and private key file, both in PEM format.

2. Update the values of the existing secrets in GCP Secrets Manager (`tfe_tls_cert_secret_arn` and `tfe_tls_privkey_secret_arn`, respectively). If you need assistance base64-encoding the files into strings prior to updating the secrets, see the examples below:

    On Linux (bash):
    ```sh
    cat new_tfe_cert.pem | base64 -w 0
    cat new_tfe_privkey.pem | base64 -w 0
    ```

   On macOS (terminal):
   ```sh
   cat new_tfe_cert.pem | base64
   cat new_tfe_privkey.pem | base64
   ```

   On Windows (PowerShell):
   ```powershell
   function ConvertTo-Base64 {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InputString
    )
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $EncodedString = [Convert]::ToBase64String($Bytes)
    return $EncodedString
   }

   Get-Content new_tfe_cert.pem -Raw | ConvertTo-Base64 -Width 0
   Get-Content new_tfe_privkey.pem -Raw | ConvertTo-Base64 -Width 0
   ```

    > **Note:**
    > When you update the value of an GCP Secrets Manager secret, the secret ARN should not change, so **no action should be needed** in terms of updating any input variable values. If the secret ARNs _were_ to change due to other circumstances, you would need to update the following input variable values with the new ARNs, and subsequently run `terraform apply` to update the TFE GCE Instance Template:
   >
    >```hcl
    >tfe_tls_cert_secret_arn    = "<new-tfe-tls-cert-secret-arn>"
    >tfe_tls_privkey_secret_arn = "<new-tfe-tls-privkey-secret-arn>"
    >```

3. During a maintenance window, terminate the running TFE GCE instance(s) which will trigger the Autoscaling Group to spawn new instance(s) from the latest version of the TFE GCE Instance Template. This process will effectively re-install TFE on the new instance(s), including the retrieval of the latest certificates from the GCP Secrets Manager secrets.

## Managed PostgreSQL Certificates

The following applies when:

- TFE is running in External Services mode

- You are connecting to a GCP managed PostgreSQL

- `pg_extra_params` is set to `sslmode=verify-ca` or `sslmode=verify-full` and `sslrootcert=/tmp/cust-ca-certificates.crt` set

When Terraform Enterprise is Installed using External Services you can optionally provide a parameter in the application settings.json file `pg_extra_params` . Typically this will be set to `sslmode=require` by most customers. In the event you have set this parameter to `sslmode=verify-ca&sslrootcert=/tmp/cust-ca-certificates.crt` or `sslmode=verify-full&sslrootcert=/tmp/cust-ca-certificates.crt` , you have also added additional certificates to your Terraform Enterprise CA bundle. These certificates were provided to you by the cloud providers documentation. Occasionally, the cloud provider may update these certificates and it is the responsibility of the Terraform Enterprise owner to monitor and update the certificates included in the CA bundle of Terraform Enterprise as well. Upon being notified by the cloud provider that their certificates are being changed, perform the following:
