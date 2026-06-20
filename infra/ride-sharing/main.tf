terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Variables
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alerts"
  type        = string
  sensitive   = true
}

variable "mapbox_access_token" {
  description = "Mapbox access token for curb data"
  type        = string
  sensitive   = true
}

variable "stripe_secret_key" {
  description = "Stripe secret key"
  type        = string
  sensitive   = true
}

variable "stripe_webhook_secret" {
  description = "Stripe webhook secret"
  type        = string
  sensitive   = true
}

variable "livekit_api_key" {
  description = "LiveKit API key"
  type        = string
  sensitive   = true
}

variable "livekit_api_secret" {
  description = "LiveKit API secret"
  type        = string
  sensitive   = true
}

variable "livekit_ws_url" {
  description = "LiveKit WebSocket URL"
  type        = string
  sensitive   = true
}

# Local values
locals {
  common_labels = {
    environment = var.environment
    project     = "ride-sharing"
    managed_by  = "terraform"
  }
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "firestore.googleapis.com",
    "bigquery.googleapis.com",
    "cloudscheduler.googleapis.com",
    "pubsub.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudtrace.googleapis.com",
    "secretmanager.googleapis.com"
  ])

  service = each.value
  project = var.project_id

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Secret Manager secrets
resource "google_secret_manager_secret" "secrets" {
  for_each = {
    slack-webhook-url     = "Slack webhook URL for notifications"
    mapbox-access-token   = "Mapbox API token for curb data"
    stripe-secret-key     = "Stripe secret key for payments"
    stripe-webhook-secret = "Stripe webhook verification secret"
    livekit-api-key       = "LiveKit API key for real-time communication"
    livekit-api-secret    = "LiveKit API secret for real-time communication"
    livekit-ws-url        = "LiveKit WebSocket URL for real-time communication"
  }

  secret_id = each.key
  labels    = local.common_labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "secret_versions" {
  for_each = {
    "slack-webhook-url"     = var.slack_webhook_url
    "mapbox-access-token"   = var.mapbox_access_token
    "stripe-secret-key"     = var.stripe_secret_key
    "stripe-webhook-secret" = var.stripe_webhook_secret
    "livekit-api-key"       = var.livekit_api_key
    "livekit-api-secret"    = var.livekit_api_secret
    "livekit-ws-url"        = var.livekit_ws_url
  }

  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value
}

# BigQuery module
module "bigquery" {
  source = "./modules/bigquery"

  project_id  = var.project_id
  environment = var.environment
  labels      = local.common_labels

  depends_on = [google_project_service.apis]
}

# Cloud Run planner service
module "planner" {
  source = "./modules/cloud_run"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  service_name = "ride-planner"
  image_url    = "gcr.io/${var.project_id}/ride-planner:latest"

  env_vars = {
    GOOGLE_CLOUD_PROJECT = var.project_id
    BQ_DATASET           = module.bigquery.dataset_id
  }

  depends_on = [google_project_service.apis]
}

# Cloud Scheduler jobs
module "scheduler" {
  source = "./modules/scheduler"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  functions_location = var.region

  depends_on = [google_project_service.apis]
}

# Pub/Sub topics for event-driven architecture
module "pubsub" {
  source = "./modules/pubsub"

  project_id  = var.project_id
  environment = var.environment
  labels      = local.common_labels

  depends_on = [google_project_service.apis]
}

# Monitoring and alerting (existing)
module "monitoring" {
  source = "./modules/monitoring"

  project_id  = var.project_id
  environment = var.environment
  labels      = local.common_labels

  depends_on = [google_project_service.apis]
}

# Service accounts and IAM
resource "google_service_account" "cloud_functions" {
  account_id   = "cloud-functions-${var.environment}"
  display_name = "Cloud Functions Service Account (${var.environment})"
  description  = "Service account for Cloud Functions with necessary permissions"
}

resource "google_service_account" "cloud_run" {
  account_id   = "cloud-run-${var.environment}"
  display_name = "Cloud Run Service Account (${var.environment})"
  description  = "Service account for Cloud Run planner service"
}

# IAM bindings for Cloud Functions
resource "google_project_iam_member" "cloud_functions_permissions" {
  for_each = toset([
    "roles/firestore.user",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/pubsub.publisher",
    "roles/pubsub.subscriber",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/cloudtrace.agent",
    "roles/secretmanager.secretAccessor"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_functions.email}"
}

# IAM bindings for Cloud Run
resource "google_project_iam_member" "cloud_run_permissions" {
  for_each = toset([
    "roles/firestore.user",
    "roles/bigquery.dataViewer",
    "roles/bigquery.jobUser",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Outputs
output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "bigquery_dataset_id" {
  description = "BigQuery dataset ID"
  value       = module.bigquery.dataset_id
}

output "planner_service_url" {
  description = "Cloud Run planner service URL"
  value       = module.planner.service_url
}

output "cloud_functions_sa_email" {
  description = "Cloud Functions service account email"
  value       = google_service_account.cloud_functions.email
}

output "cloud_run_sa_email" {
  description = "Cloud Run service account email"
  value       = google_service_account.cloud_run.email
} 