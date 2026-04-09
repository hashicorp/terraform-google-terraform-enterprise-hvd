# Example Scenario - Docker | Ubuntu | Internal passthrough Network Load Balancer (NLB)


| Configuration               | Value                        |
|-----------------------------|------------------------------|
| Operational mode            | `active-active`              |
| Container runtime           | `docker`                     |
| Operating system            | `ubuntu`                     |
| Load balancer type          | `nlb` (TCP/Layer 4)          |
| Load balancer scheme        | `internal` (private)         |
| Log forwarding destination  | `stackdriver`                |

The Admin Console remains disabled by default in this example. Set `tfe_admin_console_disabled = false` and provide `cidr_allow_ingress_tfe_admin_console` if you need operator access to the admin endpoint.
