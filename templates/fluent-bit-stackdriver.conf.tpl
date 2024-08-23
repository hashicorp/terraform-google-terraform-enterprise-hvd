[OUTPUT]
    Name       stackdriver
    Match      *
    location   ${region}
    namespace  terraform_enterprise
    node_id    ${friendly_name_prefix}-tfe
    resource   generic_node