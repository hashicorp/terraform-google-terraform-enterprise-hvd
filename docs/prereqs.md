# Prereqs Reference

This page contains explanations and sample Terraform code snippets to assist with the creation of the module prerequisites.

## Networking

### VM subnet with Private Google Access

Private Google Access enables GCE VM instances with internal IP addresses only in your VPC subnet to access Google APIs and services over the GCP internal network rather than traversing the public Internet. For TFE deployments, we want this enabled so that the TFE GCE VM instances can access the TFE GCS bucket (object storage) privately and securely. Refer to the [Private Google Access](https://cloud.google.com/vpc/docs/private-google-access) docs for more details.

```hcl
resource "google_compute_subnetwork" "tfe_vm" {
  name                     = "tfe-vm-subnet"
  network                  = "<tfe-vpc-network-id>"
  purpose                  = "PRIVATE"
  ip_cidr_range            = "10.0.1.0/24"
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}
```

The boolean `private_ip_google_access` being set to `true` is what enables Private Google Access on your subnet.

### Private Service Access (PSA)

Private Service Access enables GCE VM instances to connect to specific Google-managed services (such as Cloud SQL, Cloud Memorystore, and others) using internal IP addresses within your VPC network. For TFE deployments, we want this configured so that the TFE GCE VM instances can connect to Cloud SQL (PostgreSQL database) and Cloud Memorystore (Redis) privately and securely.

The `google_compute_global_address` resource allocates a non-overlapping IPv4 address range within your VPC network, and the `google_service_networking_connection` resource creates the private connection to your VPC network. Refer to the [Private Service Access](https://cloud.google.com/vpc/docs/private-services-access) docs for more details.

```hcl
resource "google_compute_global_address" "psa" {
  name          = "tfe-private-service-access"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = "<tfe-vpc-network-id>"
}

resource "google_service_networking_connection" "psa" {
  network                 = "<tfe-vpc-network-id>"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]
}
```

## TFE "Bootstrap" Secrets

| Secret                                           |  Module Input                       |
|--------------------------------------------------|-------------------------------------|
| TFE license file                                 | `tfe_license_secret_id`             |
| TFE encryption password                          | `tfe_encryption_password_secret_id` |
| TFE database password                            | `tfe_database_password_secret_id`   |
| TFE TLS certificate (base64-encoded)             | `tfe_tls_cert_secret_id`            |
| TFE TLS certificate private key (base64-encoded) | `tfe_tls_privkey_secret_id`         |
| TFE TLS CA bundle (base64-encoded)               | `tfe_tls_ca_bundle_secret_id`       |

### Secrets Formatting

#### TFE license file

- This value should be the raw contents of your TFE license file

Example:

```shell-session
cat terraform.hclic
```

#### TFE encryption password

- This value should be randomly generated characters
- Special characters are OK to use here

#### TFE database password

- This value should be randomly generated characters between 8 and 99 characters in length
- Must contain at least one uppercase letter, one lowercase letter, and one digit or special character

#### TFE TLS certificates

- Start off with your certificate files in PEM format
- These values should be base64-encoded
- Ensure your command line interface (CLI) does not automatically inject new line characters during the base64-encoding

Example on macOS Terminal:

```shell-session
cat tfe_cert.pem | base64
cat tfe_privkey.pem | base64
cat tfe_ca_bundle.pem | base64
```

Example on Linux Bash shell:

```shell-session
cat tfe_cert.pem | base64 -w 0
cat tfe_privkey.pem | base64 -w 0
cat tfe_ca_bundle.pem | base64 -w 0
```
