# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.6"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.6"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}