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

# Pub/Sub topics for event-driven architecture
locals {
  topics = {
    # Core ride events
    ride-events = {
      description = "Ride lifecycle events (created, matched, completed, cancelled)"
      retention   = "7d"
    }

    # Driver events
    driver-events = {
      description = "Driver status changes (online, offline, location updates)"
      retention   = "24h"
    }

    # Pricing events
    pricing-events = {
      description = "Surge pricing and fare calculation events"
      retention   = "7d"
    }

    # Alert events
    alert-events = {
      description = "System alerts and notifications"
      retention   = "30d"
    }

    # Analytics events
    analytics-events = {
      description = "Events for analytics and ML model training"
      retention   = "30d"
    }

    # Dead letter queue
    dead-letter = {
      description = "Failed message processing queue"
      retention   = "7d"
    }
  }
}

# Create Pub/Sub topics
resource "google_pubsub_topic" "topics" {
  for_each = local.topics

  name    = "${each.key}-${var.environment}"
  project = var.project_id
  labels  = var.labels

  message_retention_duration = each.value.retention

  message_storage_policy {
    allowed_persistence_regions = ["us-central1", "us-east1"]
  }
}

# Create subscriptions for each topic
resource "google_pubsub_subscription" "cloud_functions_subscriptions" {
  for_each = local.topics

  name    = "${each.key}-cf-${var.environment}"
  topic   = google_pubsub_topic.topics[each.key].name
  project = var.project_id
  labels  = var.labels

  # Acknowledgment deadline
  ack_deadline_seconds = 60

  # Message retention
  message_retention_duration = "1200s" # 20 minutes

  # Retry policy
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  # Dead letter policy (except for the dead-letter topic itself)
  dynamic "dead_letter_policy" {
    for_each = each.key != "dead-letter" ? [1] : []
    content {
      dead_letter_topic     = google_pubsub_topic.topics["dead-letter"].id
      max_delivery_attempts = 5
    }
  }

  # Push configuration for Cloud Functions
  push_config {
    push_endpoint = "https://${var.project_id}.cloudfunctions.net/pubsub-${each.key}-handler"

    attributes = {
      x-goog-version = "v1"
    }

    oidc_token {
      service_account_email = data.google_service_account.pubsub.email
    }
  }

  # Filter for specific event types (example)
  dynamic "filter" {
    for_each = each.key == "ride-events" ? [1] : []
    content {
      # Only process high-priority ride events
      filter = "attributes.priority = \"high\" OR attributes.event_type = \"ride_completed\""
    }
  }
}

# Analytics subscription with pull delivery
resource "google_pubsub_subscription" "analytics_subscriptions" {
  for_each = {
    ride-events    = "ride-analytics"
    driver-events  = "driver-analytics"
    pricing-events = "pricing-analytics"
  }

  name    = "${each.value}-${var.environment}"
  topic   = google_pubsub_topic.topics[each.key].name
  project = var.project_id
  labels  = var.labels

  # Longer acknowledgment deadline for batch processing
  ack_deadline_seconds = 300

  # Longer message retention for analytics
  message_retention_duration = "3600s" # 1 hour

  # No push config - these are pull subscriptions for batch processing

  retry_policy {
    minimum_backoff = "60s"
    maximum_backoff = "3600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.topics["dead-letter"].id
    max_delivery_attempts = 3
  }
}

# BigQuery subscription for direct streaming
resource "google_pubsub_subscription" "bigquery_subscriptions" {
  for_each = {
    ride-events   = "bq-ride-events"
    driver-events = "bq-driver-events"
  }

  name    = "${each.value}-${var.environment}"
  topic   = google_pubsub_topic.topics[each.key].name
  project = var.project_id
  labels  = var.labels

  ack_deadline_seconds       = 600
  message_retention_duration = "7200s" # 2 hours

  # BigQuery subscription configuration
  bigquery_config {
    table            = "${var.project_id}.ride_sharing_${var.environment}.${replace(each.key, "-", "_")}_stream"
    use_topic_schema = false
    write_metadata   = true
  }

  retry_policy {
    minimum_backoff = "30s"
    maximum_backoff = "1800s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.topics["dead-letter"].id
    max_delivery_attempts = 5
  }
}

# Service account for Pub/Sub
resource "google_service_account" "pubsub" {
  account_id   = "pubsub-${var.environment}"
  display_name = "Pub/Sub Service Account (${var.environment})"
  description  = "Service account for Pub/Sub push subscriptions"
  project      = var.project_id
}

# Get the Pub/Sub service account
data "google_service_account" "pubsub" {
  account_id = google_service_account.pubsub.account_id
  project    = var.project_id
  depends_on = [google_service_account.pubsub]
}

# IAM bindings for Pub/Sub service account
resource "google_project_iam_member" "pubsub_permissions" {
  for_each = toset([
    "roles/cloudfunctions.invoker",
    "roles/pubsub.publisher",
    "roles/bigquery.dataEditor"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.pubsub.email}"
}

# IAM bindings for dead letter topic
resource "google_pubsub_topic_iam_member" "dead_letter_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.topics["dead-letter"].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Get current project information
data "google_project" "current" {
  project_id = var.project_id
}

# Create schemas for structured messages
resource "google_pubsub_schema" "ride_event_schema" {
  name    = "ride-event-schema-${var.environment}"
  type    = "AVRO"
  project = var.project_id
  definition = jsonencode({
    type = "record"
    name = "RideEvent"
    fields = [
      {
        name = "ride_id"
        type = "string"
      },
      {
        name = "event_type"
        type = {
          type = "enum"
          name = "EventType"
          symbols = [
            "RIDE_CREATED",
            "RIDE_MATCHED",
            "RIDE_STARTED",
            "RIDE_COMPLETED",
            "RIDE_CANCELLED"
          ]
        }
      },
      {
        name        = "timestamp"
        type        = "long"
        logicalType = "timestamp-millis"
      },
      {
        name    = "driver_id"
        type    = ["null", "string"]
        default = null
      },
      {
        name = "rider_id"
        type = "string"
      },
      {
        name = "pickup_location"
        type = {
          type = "record"
          name = "Location"
          fields = [
            { name = "lat", type = "double" },
            { name = "lng", type = "double" }
          ]
        }
      },
      {
        name = "dropoff_location"
        type = "Location"
      },
      {
        name    = "fare_amount"
        type    = ["null", "double"]
        default = null
      }
    ]
  })
}

# Outputs
output "topics" {
  description = "Created Pub/Sub topics"
  value = {
    for k, v in google_pubsub_topic.topics : k => {
      name = v.name
      id   = v.id
    }
  }
}

output "subscriptions" {
  description = "Created Pub/Sub subscriptions"
  value = merge(
    {
      for k, v in google_pubsub_subscription.cloud_functions_subscriptions : "${k}-cf" => {
        name = v.name
        id   = v.id
      }
    },
    {
      for k, v in google_pubsub_subscription.analytics_subscriptions : "${k}-analytics" => {
        name = v.name
        id   = v.id
      }
    },
    {
      for k, v in google_pubsub_subscription.bigquery_subscriptions : "${k}-bq" => {
        name = v.name
        id   = v.id
      }
    }
  )
}

output "pubsub_service_account" {
  description = "Email of the Pub/Sub service account"
  value       = google_service_account.pubsub.email
}

output "schemas" {
  description = "Created Pub/Sub schemas"
  value = {
    ride_events = google_pubsub_schema.ride_event_schema.name
  }
} 