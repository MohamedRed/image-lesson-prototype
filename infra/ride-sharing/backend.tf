# Terraform backend configuration for remote state storage
# This file configures Terraform to store state in Google Cloud Storage
# with state locking via Cloud Storage object versioning

terraform {
  backend "gcs" {
    bucket = "liive-terraform-state"
    prefix = "terraform/state"

    # Optional: Enable object versioning for state locking
    # This is automatically handled by GCS when versioning is enabled
  }

  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
} 