# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "tfe_url" {
  value       = module.tfe.url
  description = "TFE URL based on `tfe_fqdn` input variable value."
}