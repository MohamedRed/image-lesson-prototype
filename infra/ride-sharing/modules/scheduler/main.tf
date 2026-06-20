variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "labels" {
  description = "Common labels to apply to resources"
  type        = map(string)
  default     = {}
}

variable "functions_location" {
  description = "Location where Cloud Functions are deployed"
  type        = string
}

# Scheduler jobs for all the Cloud Functions
locals {
  scheduler_jobs = {
    # S4 - Congestion Cron (every minute)
    congestion-cron = {
      schedule    = "*/1 * * * *"
      description = "Reconcile driver and pickup zone congestion metrics"
      function    = "congestionCron"
      timeout     = "60s"
    }

    # S6b - Hourly resource sweep
    hourly-sweep = {
      schedule    = "0 * * * *"
      description = "Clean up stuck ride legs older than 6 hours"
      function    = "hourlySweep"
      timeout     = "300s"
    }

    # S7 - Nightly curb import (3 AM daily)
    nightly-curb-import = {
      schedule    = "0 3 * * *"
      description = "Import latest curb data from Mapbox"
      function    = "nightlyCurbImport"
      timeout     = "1800s"
    }

    # S8 - Forecast heat map (every 10 minutes)
    forecast-heat-map = {
      schedule    = "*/10 * * * *"
      description = "Generate demand/supply forecast using BigQuery ML"
      function    = "forecastHeatMap"
      timeout     = "300s"
    }

    # Gender pool KPI analysis (hourly)
    gender-pool-kpi = {
      schedule    = "0 * * * *"
      description = "Analyze gender pool starvation and send alerts"
      function    = "genderPoolKpi"
      timeout     = "300s"
    }

    # BigQuery export (every 10 minutes)
    bigquery-export = {
      schedule    = "*/10 * * * *"
      description = "Export ride requests to BigQuery for analytics"
      function    = "exportRideRequests"
      timeout     = "300s"
    }

    # Payout scheduler (daily at 2 AM)
    payout-scheduler = {
      schedule    = "0 2 * * *"
      description = "Process daily driver payouts via Stripe"
      function    = "payoutScheduler"
      timeout     = "1800s"
    }

    # BigQuery aggregation refresh (every hour at :15)
    bigquery-aggregation = {
      schedule    = "15 * * * *"
      description = "Refresh hourly demand/supply aggregation in BigQuery"
      function    = "refreshBigQueryAggregation"
      timeout     = "600s"
    }
  }
}

# Create scheduler jobs
resource "google_cloud_scheduler_job" "scheduled_functions" {
  for_each = local.scheduler_jobs

  name             = "${each.key}-${var.environment}"
  description      = each.value.description
  schedule         = each.value.schedule
  time_zone        = "UTC"
  attempt_deadline = each.value.timeout
  region           = var.region
  project          = var.project_id

  retry_config {
    retry_count          = 3
    max_retry_duration   = "600s"
    max_backoff_duration = "60s"
    min_backoff_duration = "5s"
    max_doublings        = 3
  }

  http_target {
    http_method = "POST"
    uri         = "https://${var.functions_location}-${var.project_id}.cloudfunctions.net/${each.value.function}"
    
    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      scheduled = true
      job_name  = each.key
      timestamp = "{{.timestamp}}"
    }))

    oidc_token {
      service_account_email = data.google_service_account.scheduler.email
      audience             = "https://${var.functions_location}-${var.project_id}.cloudfunctions.net/${each.value.function}"
    }
  }
}

# Service account for Cloud Scheduler
resource "google_service_account" "scheduler" {
  account_id   = "cloud-scheduler-${var.environment}"
  display_name = "Cloud Scheduler Service Account (${var.environment})"
  description  = "Service account for Cloud Scheduler to invoke Cloud Functions"
  project      = var.project_id
}

# IAM binding for scheduler to invoke functions
resource "google_project_iam_member" "scheduler_invoker" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.scheduler.email}"
}

# Data source to get the scheduler service account
data "google_service_account" "scheduler" {
  account_id = google_service_account.scheduler.account_id
  project    = var.project_id
  depends_on = [google_service_account.scheduler]
}

# Additional scheduler job for BigQuery procedure
resource "google_cloud_scheduler_job" "bigquery_procedure" {
  name             = "bigquery-refresh-${var.environment}"
  description      = "Refresh BigQuery hourly aggregation procedure"
  schedule         = "30 * * * *" # Every hour at :30
  time_zone        = "UTC"
  attempt_deadline = "600s"
  region           = var.region
  project          = var.project_id

  retry_config {
    retry_count          = 2
    max_retry_duration   = "300s"
    max_backoff_duration = "30s"
    min_backoff_duration = "5s"
    max_doublings        = 2
  }

  http_target {
    http_method = "POST"
    uri         = "https://bigquery.googleapis.com/bigquery/v2/projects/${var.project_id}/jobs"
    
    headers = {
      "Content-Type"  = "application/json"
      "Authorization" = "Bearer {{.token}}"
    }

    body = base64encode(jsonencode({
      configuration = {
        query = {
          query      = "CALL `ride_sharing_${var.environment}.refresh_hourly_aggregation`();"
          useLegacySql = false
        }
      }
    }))

    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                = "https://www.googleapis.com/auth/bigquery"
    }
  }
}

# IAM binding for BigQuery access
resource "google_project_iam_member" "scheduler_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_project_iam_member" "scheduler_bigquery_data" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.scheduler.email}"
}

# Outputs
output "scheduler_jobs" {
  description = "List of created scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.scheduled_functions : k => {
      name     = v.name
      schedule = v.schedule
    }
  }
}

output "scheduler_service_account" {
  description = "Email of the scheduler service account"
  value       = google_service_account.scheduler.email
} 