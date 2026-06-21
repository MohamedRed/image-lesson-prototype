# Alert policy for BigQuery aggregation failures
resource "google_monitoring_alert_policy" "bigquery_aggregation_failure" {
  display_name = "BigQuery Aggregation Procedure Failure"
  combiner     = "OR"

  conditions {
    display_name = "BigQuery aggregation failure detected"

    condition_matched_log {
      filter = <<-EOT
        resource.type="global"
        logName="projects/${var.project_id}/logs/bigquery-aggregation"
        jsonPayload.labels.status="failure"
        jsonPayload.labels.component="bigquery-aggregation"
      EOT

      label_extractors = {
        "build_id" = "EXTRACT(jsonPayload.labels.build_id)"
        "project"  = "EXTRACT(jsonPayload.labels.project)"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s" # 30 minutes
  }

  notification_channels = [
    google_monitoring_notification_channel.slack.id
  ]

  documentation {
    content = <<-EOT
      ## BigQuery Aggregation Failure Alert
      
      This alert fires when BigQuery aggregation procedures fail during the CI/CD pipeline.
      
      ### Immediate Actions:
      1. Check Cloud Build logs for the failing build
      2. Verify BigQuery dataset and table permissions
      3. Check if required source tables have data
      4. Validate SQL syntax in aggregation procedures
      
      ### Investigation Steps:
      1. Navigate to BigQuery console
      2. Check procedure execution history
      3. Review error messages in Cloud Logging
      4. Verify data freshness in source tables
      
      ### Escalation:
      - If procedures continue to fail after 3 attempts, escalate to data engineering team
      - For ML model issues, contact the ML platform team
    EOT

    mime_type = "text/markdown"
  }
}

# Custom metric for tracking aggregation success rate
resource "google_logging_metric" "bigquery_aggregation_success_rate" {
  name   = "bigquery_aggregation_success_rate"
  filter = <<-EOT
    resource.type="global"
    logName="projects/${var.project_id}/logs/bigquery-aggregation"
    jsonPayload.labels.component="bigquery-aggregation"
  EOT

  label_extractors = {
    "status"   = "EXTRACT(jsonPayload.labels.status)"
    "build_id" = "EXTRACT(jsonPayload.labels.build_id)"
  }

  metric_descriptor {
    metric_kind = "GAUGE"
    value_type  = "INT64"
  }

  value_extractor = "1"
}

# Alert for low aggregation success rate
resource "google_monitoring_alert_policy" "bigquery_aggregation_success_rate" {
  display_name = "BigQuery Aggregation Success Rate Low"
  combiner     = "OR"

  conditions {
    display_name = "Aggregation success rate below 90%"

    condition_threshold {
      filter          = "resource.type=\"global\" AND metric.type=\"logging.googleapis.com/user/bigquery_aggregation_success_rate\""
      duration        = "300s"
      comparison      = "COMPARISON_LESS_THAN"
      threshold_value = 0.9

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["metric.label.status"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.slack.id
  ]

  documentation {
    content = <<-EOT
      ## BigQuery Aggregation Success Rate Alert
      
      This alert fires when the success rate of BigQuery aggregation procedures drops below 90% over a 5-minute window.
      
      ### Possible Causes:
      - Infrastructure issues with BigQuery
      - Data quality problems in source tables
      - Resource constraints during peak usage
      - Schema changes breaking procedures
      
      ### Resolution Steps:
      1. Check recent Cloud Build executions
      2. Review BigQuery job history for failed queries
      3. Validate source data integrity
      4. Check for any recent schema changes
    EOT

    mime_type = "text/markdown"
  }
}

# Dashboard for BigQuery aggregation monitoring
resource "google_monitoring_dashboard" "bigquery_aggregation" {
  dashboard_json = jsonencode({
    displayName = "BigQuery Aggregation Monitoring"

    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Aggregation Success Rate"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"global\" AND metric.type=\"logging.googleapis.com/user/bigquery_aggregation_success_rate\""
                  aggregation = {
                    alignmentPeriod    = "300s"
                    perSeriesAligner   = "ALIGN_RATE"
                    crossSeriesReducer = "REDUCE_MEAN"
                    groupByFields      = ["metric.label.status"]
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
          xPos   = 6
          widget = {
            title = "Aggregation Execution Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"global\" AND metric.type=\"logging.googleapis.com/user/bigquery_aggregation_success_rate\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Executions per minute"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 12
          height = 4
          yPos   = 4
          widget = {
            title = "Recent Aggregation Logs"
            logsPanel = {
              filter = <<-EOT
                resource.type="global"
                logName="projects/${var.project_id}/logs/bigquery-aggregation"
                jsonPayload.labels.component="bigquery-aggregation"
              EOT
            }
          }
        }
      ]
    }
  })
}

# Uptime check for BigQuery dataset availability
resource "google_monitoring_uptime_check_config" "bigquery_dataset_check" {
  display_name = "BigQuery Dataset Availability"
  timeout      = "10s"
  period       = "300s" # Check every 5 minutes

  http_check {
    path           = "/bigquery/v2/projects/${var.project_id}/datasets/ride_analytics"
    port           = "443"
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"

    auth_info {
      username = "bigquery-monitoring@${var.project_id}.iam.gserviceaccount.com"
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = "bigquery.googleapis.com"
    }
  }

  content_matchers {
    content = "ride_analytics"
    matcher = "CONTAINS_STRING"
  }
} 