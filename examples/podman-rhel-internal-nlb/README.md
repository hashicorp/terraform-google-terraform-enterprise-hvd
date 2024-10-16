# Example Scenario - Podman | RHEL | Internal passthrough Network Load Balancer (NLB)


| Configuration               | Value                        |
|-----------------------------|------------------------------|
| Operational mode            | `active-active`              |
| Container runtime           | `podman`                     |
| Operating system            | `rhel`                       |
| Load balancer type          | `nlb` (TCP/Layer 4)          |
| Load balancer scheme        | `internal` (private)         |
| Log forwarding destination  | `stackdriver`                |