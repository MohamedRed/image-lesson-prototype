variable "project_id" {
  description = "GCP project ID"
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

# Notification channels
resource "google_monitoring_notification_channel" "slack" {
  display_name = "Slack Channel (${var.environment})"
  type         = "slack"
  project      = var.project_id
  labels = {
    channel_name = "#alerts-${var.environment}"
  }
  
  # Get webhook URL from Secret Manager
  user_labels = var.labels
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "Engineering Team Email (${var.environment})"
  type         = "email"
  project      = var.project_id
  labels = {
    email_address = "engineering@company.com"
  }
  
  user_labels = var.labels
}

# Alert policies
resource "google_monitoring_alert_policy" "function_errors" {
  display_name = "Cloud Function Error Rate (${var.environment})"
  combiner     = "OR"
  project      = var.project_id
  
  conditions {
    display_name = "Function errors > 5/min"
    condition_threshold {
      filter          = "resource.type=\"cloud_function\" AND metric.type=\"cloudfunctions.googleapis.com/function/execution_count\" AND metric.labels.status!=\"ok\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "300s"
      
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields     = ["resource.labels.function_name"]
      }
    }
  }
  
  notification_channels = [
    google_monitoring_notification_channel.slack.id,
    google_monitoring_notification_channel.email.id
  ]
  
  alert_strategy {
    auto_close = "1800s" # 30 minutes
  }
  
  user_labels = var.labels
}

resource "google_monitoring_alert_policy" "function_latency" {
  display_name = "Cloud Function P95 Latency (${var.environment})"
  combiner     = "OR"
  project      = var.project_id
  
  conditions {
    display_name = "P95 latency > 2s"
    condition_threshold {
      filter          = "resource.type=\"cloud_function\" AND metric.type=\"cloudfunctions.googleapis.com/function/execution_times\""
      comparison      = "COMPARISON_GT"
      threshold_value = 2000
      duration        = "300s"
      
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields     = ["resource.labels.function_name"]
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.slack.id]
  user_labels = var.labels
}

resource "google_monitoring_alert_policy" "unmatched_rides" {
  display_name = "Unmatched Ride Requests (${var.environment})"
  combiner     = "OR"
  project      = var.project_id
  
  conditions {
    display_name = "Unmatched rides > 10/min"
    condition_threshold {
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"custom.googleapis.com/singleHopMatcher/unmatched/count\""
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "300s"
      
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
  
  notification_channels = [
    google_monitoring_notification_channel.slack.id,
    google_monitoring_notification_channel.email.id
  ]
  
  user_labels = var.labels
}

# Cloud Run monitoring
resource "google_monitoring_alert_policy" "cloud_run_errors" {
  display_name = "Cloud Run Error Rate (${var.environment})"
  combiner     = "OR"
  project      = var.project_id
  
  conditions {
    display_name = "Cloud Run 5xx errors > 5%"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.05
      duration        = "300s"
      
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields     = ["resource.labels.service_name"]
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.slack.id]
  user_labels = var.labels
}

# Firestore monitoring
resource "google_monitoring_alert_policy" "firestore_errors" {
  display_name = "Firestore Error Rate (${var.environment})"
  combiner     = "OR"
  project      = var.project_id
  
  conditions {
    display_name = "Firestore errors > 1%"
    condition_threshold {
      filter          = "resource.type=\"firestore_database\" AND metric.type=\"firestore.googleapis.com/api/request_count\" AND metric.labels.response_code!=\"OK\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.01
      duration        = "300s"
      
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.slack.id]
  user_labels = var.labels
}

# BigQuery monitoring
resource "google_monitoring_alert_policy" "bigquery_job_failures" {
  display_name = "BigQuery Job Failures (${var.environment})"
  combiner     = "OR"
  project      = var.project_id
  
  conditions {
    display_name = "BigQuery job failures > 5/hour"
    condition_threshold {
      filter          = "resource.type=\"bigquery_project\" AND metric.type=\"bigquery.googleapis.com/job/num_failed_jobs\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "300s"
      
      aggregations {
        alignment_period     = "3600s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.slack.id]
  user_labels = var.labels
}

# Custom business metrics alerts
resource "google_monitoring_alert_policy" "ride_completion_rate" {
  display_name = "Low Ride Completion Rate (${var.environment})"
  combiner     = "OR"
  project      = var.project_id
  
  conditions {
    display_name = "Ride completion rate < 85%"
    condition_threshold {
      filter          = "resource.type=\"global\" AND metric.type=\"custom.googleapis.com/rides/completion_rate\""
      comparison      = "COMPARISON_LT"
      threshold_value = 0.85
      duration        = "900s" # 15 minutes
      
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
      }
    }
  }
  
  notification_channels = [
    google_monitoring_notification_channel.slack.id,
    google_monitoring_notification_channel.email.id
  ]
  
  user_labels = var.labels
}

resource "google_monitoring_alert_policy" "driver_utilization" {
  display_name = "Low Driver Utilization (${var.environment})"
  combiner     = "OR"
  project      = var.project_id
  
  conditions {
    display_name = "Driver utilization < 60%"
    condition_threshold {
      filter          = "resource.type=\"global\" AND metric.type=\"custom.googleapis.com/drivers/utilization_rate\""
      comparison      = "COMPARISON_LT"
      threshold_value = 0.60
      duration        = "1800s" # 30 minutes
      
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.slack.id]
  user_labels = var.labels
}

# Security and fraud alerts
resource "google_monitoring_alert_policy" "location_spoofing_alerts" {
  display_name = "High Location Spoofing Activity (${var.environment})"
  combiner     = "OR"
  project      = var.project_id
  
  conditions {
    display_name = "Location spoofing alerts > 10/hour"
    condition_threshold {
      filter          = "resource.type=\"global\" AND metric.type=\"custom.googleapis.com/security/location_spoofing_alerts\""
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "300s"
      
      aggregations {
        alignment_period     = "3600s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
  
  notification_channels = [
    google_monitoring_notification_channel.slack.id,
    google_monitoring_notification_channel.email.id
  ]
  
  user_labels = var.labels
}

resource "google_monitoring_alert_policy" "inventory_mismatches" {
  display_name = "Critical Inventory Mismatches (${var.environment})"
  combiner     = "OR"
  project      = var.project_id
  
  conditions {
    display_name = "Critical inventory mismatches > 0"
    condition_threshold {
      filter          = "resource.type=\"global\" AND metric.type=\"custom.googleapis.com/inventory/critical_mismatches\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "60s"
      
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
  
  notification_channels = [
    google_monitoring_notification_channel.slack.id,
    google_monitoring_notification_channel.email.id
  ]
  
  user_labels = var.labels
}

# Uptime checks
resource "google_monitoring_uptime_check_config" "cloud_run_health" {
  display_name = "Cloud Run Health Check (${var.environment})"
  timeout      = "10s"
  period       = "60s"
  project      = var.project_id
  
  http_check {
    path         = "/health"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }
  
  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = "${var.environment}-ride-planner-service.run.app"
    }
  }
  
  content_matchers {
    content = "healthy"
    matcher = "CONTAINS_STRING"
  }
}

# Dashboard
resource "google_monitoring_dashboard" "ride_sharing_overview" {
  dashboard_json = jsonencode({
    displayName = "Ride Sharing Overview (${var.environment})"
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Active Rides"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"global\" AND metric.type=\"custom.googleapis.com/rides/active_count\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Driver Utilization Rate"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"global\" AND metric.type=\"custom.googleapis.com/drivers/utilization_rate\""
                  aggregation = {
                    alignmentPeriod    = "300s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_MEAN"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          width  = 12
          height = 4
          widget = {
            title = "Function Execution Times"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"cloud_function\" AND metric.type=\"cloudfunctions.googleapis.com/function/execution_times\""
                      aggregation = {
                        alignmentPeriod     = "60s"
                        perSeriesAligner    = "ALIGN_PERCENTILE_95"
                        crossSeriesReducer  = "REDUCE_MEAN"
                        groupByFields       = ["resource.labels.function_name"]
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
              yAxis = {
                label = "Latency (ms)"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
  
  project = var.project_id
}

# Outputs
output "notification_channels" {
  description = "Created notification channels"
  value = {
    slack = google_monitoring_notification_channel.slack.id
    email = google_monitoring_notification_channel.email.id
  }
}

output "alert_policies" {
  description = "Created alert policies"
  value = {
    function_errors         = google_monitoring_alert_policy.function_errors.id
    function_latency        = google_monitoring_alert_policy.function_latency.id
    unmatched_rides        = google_monitoring_alert_policy.unmatched_rides.id
    cloud_run_errors       = google_monitoring_alert_policy.cloud_run_errors.id
    firestore_errors       = google_monitoring_alert_policy.firestore_errors.id
    bigquery_job_failures  = google_monitoring_alert_policy.bigquery_job_failures.id
    ride_completion_rate   = google_monitoring_alert_policy.ride_completion_rate.id
    driver_utilization     = google_monitoring_alert_policy.driver_utilization.id
    location_spoofing      = google_monitoring_alert_policy.location_spoofing_alerts.id
    inventory_mismatches   = google_monitoring_alert_policy.inventory_mismatches.id
  }
}

output "dashboard_url" {
  description = "URL of the monitoring dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.ride_sharing_overview.id}?project=${var.project_id}"
} 