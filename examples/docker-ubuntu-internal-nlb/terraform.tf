terraform {
  required_version = "~> 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.39"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.39"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
provider "google" {
  project = var.project_id
  region  = var.region
}
