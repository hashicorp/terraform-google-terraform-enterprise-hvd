# Example Scenario - Docker | Ubuntu | Internal passthrough Network Load Balancer (NLB)


| Configuration               | Value                        |
|-----------------------------|------------------------------|
| Operational mode            | `active-active`              |
| Container runtime           | `docker`                     |
| Operating system            | `ubuntu`                     |
| Load balancer type          | `nlb` (TCP/Layer 4)          |
| Load balancer scheme        | `internal` (private)         |
| Log forwarding destination  | `stackdriver`                |

Explorer is disabled by default in this example. Set `tfe_explorer_enabled = true` to have the module provision a dedicated Explorer Cloud SQL instance automatically, or pass explicit Explorer database settings to use an existing database.
