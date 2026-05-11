# Example Scenario - Podman | RHEL | Internal passthrough Network Load Balancer (NLB)


| Configuration               | Value                        |
|-----------------------------|------------------------------|
| Operational mode            | `active-active`              |
| Container runtime           | `podman`                     |
| Operating system            | `rhel`                       |
| Load balancer type          | `nlb` (TCP/Layer 4)          |
| Load balancer scheme        | `internal` (private)         |
| Log forwarding destination  | `stackdriver`                |

The Admin Console remains disabled by default in this example. Set `tfe_admin_console_disabled = false` and provide `cidr_allow_ingress_tfe_admin_console` if you need operator access to the admin endpoint.

This example keeps the primary TFE endpoint internal by default. You can optionally add `tfe_hostname_secondary` plus `create_secondary_tfe_lb = true` to publish a dedicated public callback hostname for OIDC, VCS webhooks, and run tasks.
