# Health ETL Service Cloud Run Configuration
resource "google_cloud_run_service" "health_etl" {
  name     = "health-etl-service"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/health-etl:latest"
        
        ports {
          container_port = 8080
        }

        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }

        env {
          name  = "NODE_ENV"
          value = "production"
        }

        resources {
          limits = {
            cpu    = "2"
            memory = "4Gi"
          }
          requests = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
      }

      # Service account with necessary permissions
      service_account_name = google_service_account.health_etl.email
      
      # Timeout for long-running ETL jobs
      timeout_seconds = 3600
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "0"
        "autoscaling.knative.dev/maxScale" = "3"
        "run.googleapis.com/cpu-throttling" = "false"
        "run.googleapis.com/execution-environment" = "gen2"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.run_api,
    google_service_account.health_etl
  ]
}

# Service account for health ETL service
resource "google_service_account" "health_etl" {
  account_id   = "health-etl-service"
  display_name = "Health ETL Service Account"
  description  = "Service account for health data ETL processing"
}

# IAM bindings for the service account
resource "google_project_iam_member" "health_etl_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.health_etl.email}"
}

resource "google_project_iam_member" "health_etl_bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.health_etl.email}"
}

resource "google_project_iam_member" "health_etl_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.health_etl.email}"
}

# Cloud Scheduler job to trigger daily ETL
resource "google_cloud_scheduler_job" "daily_etl" {
  name      = "daily-health-etl"
  region    = var.region
  schedule  = "0 2 * * *"  # 2 AM UTC daily
  time_zone = "UTC"

  http_target {
    http_method = "POST"
    uri         = "${google_cloud_run_service.health_etl.status[0].url}/etl/daily"
    
    headers = {
      "Content-Type" = "application/json"
    }

    oidc_token {
      service_account_email = google_service_account.health_etl.email
      audience             = google_cloud_run_service.health_etl.status[0].url
    }
  }

  depends_on = [
    google_cloud_run_service.health_etl,
    google_project_service.scheduler_api
  ]
}

# BigQuery scheduled queries
resource "google_bigquery_data_transfer_config" "daily_aggregates" {
  display_name           = "Daily Health Aggregates"
  location              = var.bq_location
  data_source_id        = "scheduled_query"
  schedule              = "every day 03:00"
  destination_dataset_id = google_bigquery_dataset.health_analytics.dataset_id

  params = {
    query                = file("${path.module}/../bigquery/scheduled-queries/daily_health_aggregates.sql")
    destination_table_name_template = "daily_aggregates"
    write_disposition              = "WRITE_APPEND"
    use_legacy_sql                 = false
  }

  depends_on = [
    google_bigquery_dataset.health_analytics,
    google_project_service.bigquerydatatransfer_api
  ]
}

resource "google_bigquery_data_transfer_config" "weekly_trends" {
  display_name           = "Weekly Health Trends"
  location              = var.bq_location
  data_source_id        = "scheduled_query"
  schedule              = "every sunday 04:00"
  destination_dataset_id = google_bigquery_dataset.health_analytics.dataset_id

  params = {
    query                = file("${path.module}/../bigquery/scheduled-queries/weekly_health_trends.sql")
    destination_table_name_template = "weekly_trends"
    write_disposition              = "WRITE_APPEND"
    use_legacy_sql                 = false
  }

  depends_on = [
    google_bigquery_dataset.health_analytics,
    google_project_service.bigquerydatatransfer_api
  ]
}

# Output the service URL
output "health_etl_service_url" {
  value = google_cloud_run_service.health_etl.status[0].url
}