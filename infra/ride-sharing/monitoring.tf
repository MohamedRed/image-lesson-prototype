resource "google_monitoring_notification_channel" "slack" {
  display_name = "Slack Channel"
  type         = "slack"
  labels = {
    channel_name = "#alerts"
  }
}

resource "google_monitoring_alert_policy" "function_errors" {
  display_name = "Function Error Rate"
  combiner     = "OR"
  conditions {
    display_name = "Errors > 5/min"
    condition_threshold {
      filter          = "metric.type=\"custom.googleapis.com/*/errors\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "0s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
  notification_channels = [google_monitoring_notification_channel.slack.id]
}

resource "google_monitoring_alert_policy" "function_latency" {
  display_name = "Function P95 Latency"
  combiner     = "OR"
  conditions {
    display_name = "P95 latency > 2s"
    condition_threshold {
      filter          = "metric.type=\"custom.googleapis.com/*/latency_ms\""
      comparison      = "COMPARISON_GT"
      threshold_value = 2000
      duration        = "0s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_NONE"
      }
    }
  }
  notification_channels = [google_monitoring_notification_channel.slack.id]
}

resource "google_monitoring_alert_policy" "unmatched_rides" {
  display_name = "Unmatched Ride Requests"
  combiner     = "OR"
  conditions {
    display_name = "Unmatched > 10/min"
    condition_threshold {
      filter          = "metric.type=\"custom.googleapis.com/singleHopMatcher/unmatched/count\""
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "0s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
  notification_channels = [google_monitoring_notification_channel.slack.id]
} 