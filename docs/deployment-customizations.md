# Deployment Customizations

This page contains various deployment customizations as it relates to creating your TFE infrastructure, and their corresponding module input variables that you may additionally set to meet your own custom requirements (where the module default values do not suffice).

## Load Balancer

This module defaults to creating an [Internal passthrough Network Load Balancer](https://cloud.google.com/load-balancing/docs/internal) (`lb_is_internal = true`)`. Creating an [External passthrough Network Load Balancer](https://cloud.google.com/load-balancing/docs/network/networklb-backend-service#architecture) instead is also supported.

### Internal passthrough Network Load Balancer (module default)

- To deploy an internal load balancer, `lb_is_internal` must be `true` (module default)
- You must provide a load balancer subnet via `lb_subnet_name`
- The load balancer subnet can be the same exact subnet as the one you specified for the VM subnet via `vm_subnet_name`, if you prefer not to separate them
- You can optionally specify an internal static IP address for the load balancer via `lb_static_ip_address` (must be a valid IP from your load balancer subnet)
- If you do not specify an internal static IP address for the load balancer, an available IP will automatically be selected from your load balancer subnet

```hcl
lb_is_internal       = true
lb_subnet_name       = "tfe-subnet"
lb_static_ip_address = "10.0.1.20" # optional
```

### External passthrough Network Load Balancer

- To deploy an external load balancer, `lb_is_internal` must be `false`
- The module will automatically provision a public IP address resource in GCP
- A load balancer subnet (`lb_subnet_name`) is _not_ needed when using an external load balancer
- A load balancer static IP address _cannot_ be set since the module will create a public IP address resource

```hcl
lb_is_internal = false
```

## DNS

This module supports optionally creating a DNS record within your existing Google Cloud DNS managed zone for your TFE FQDN.

- The DNS record name is the value of the `tfe_fqdn` module input
- Your `tfe_fqdn` must contain the DNS name of your existing Cloud DNS zone after the hostname portion
- The DNS record will resolve to the TFE load balancer IP address determined by the module
- If your TFE load balancer is internal (`lb_is_internal = true`), then your existing Cloud DNS zone must be **private**
- If your TFE load balancer is external (`lb_is_internal = false`), then your existing Cloud DNS zone must be **public**

```hcl
create_tfe_cloud_dns_record = true
cloud_dns_managed_zone_name = "cloud-dns-managed-zone-name"
```

## KMS

This module supports optionally configuring a KMS customer managed encryption key (CMEK) to encrypt some of your GCP resources.

### Cloud SQL (PostgreSQL)

```hcl
postgres_kms_keyring_name = "tfe-postgres-keyring"
postgres_kms_cmek_name    = "tfe-postgres-cmek"
```

The geographic location (region) of the Postgres key ring must match the location of the TFE Cloud SQL for PostgreSQL database instance. This location would be the GCP region that you deployed TFE in.

### GCS bucket

```hcl
gcs_kms_keyring_name = "tfe-gcs-keyring"
gcs_kms_cmek_name    = "tfe-gcs-cmek"
```

The geographic location (region) of the GCS key ring must match the location of the TFE GCS bucket. This location would be the value of `gcs_location`, which defaults to a multi-regional location.

### Cloud Memorystore (Redis)

```hcl
redis_kms_keyring_name = "tfe-redis-keyring"
redis_kms_cmek_name    = "tfe-redis-keyring"
```

The geographic location (region) of the Redis key ring must match the location of the TFE Redis instance. This location would be the GCP that you deployed TFE in.

## SSH to GCE VMs

This module supports two ways to configure SSH access to your TFE GCE VM instances.

### 1. IAP Tunneling (module default)

```hcl
allow_ingress_vm_ssh_from_iap = true
```

This will create a firewall rule with the GCP IAP servers as the source ranges, and the TFE GCE VM instances as the target. From here, you are able to SSH to your TFE VMs

```shell-session
gcloud compute ssh <tfe-vm-name> --tunnel-through-iap
```

### 2. Public key

If you do not want to allow firewall access from the GCP IAP servers, then you can configure a public key and firewall rule using the following:

```hcl
cidr_allow_ingress_vm_ssh = ["192.168.1.0/24", "10.0.1.0/24"] # CIDR blocks of users/clients managing TFE servers
gce_ssh_public_key        = "<tfe-gce-vm-ssh-public-key>"
```

## Custom Startup Script

While this is not recommended, this module supports the ability to use your own custom startup script to install TFE.

- The script must exist in a folder named `./templates` within your current working directory that you are running Terraform from
- The script must contain all of the variables (denoted by `${example-variable}`) in the module-level TFE startup script (see `./templates/tfe_startup_script.sh.tpl`)
- Use at your own peril
