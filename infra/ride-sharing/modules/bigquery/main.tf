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

# BigQuery dataset
resource "google_bigquery_dataset" "ride_sharing" {
  dataset_id  = "ride_sharing_${var.environment}"
  project     = var.project_id
  description = "Ride sharing platform analytics and ML models (${var.environment})"
  location    = "US"

  labels = var.labels

  delete_contents_on_destroy = var.environment != "prod"

  access {
    role          = "OWNER"
    user_by_email = data.google_client_openid_userinfo.me.email
  }

  access {
    role   = "READER"
    domain = "google.com"
  }

  access {
    role          = "WRITER"
    special_group = "projectWriters"
  }
}

data "google_client_openid_userinfo" "me" {}

# Ride requests table
resource "google_bigquery_table" "ride_requests" {
  dataset_id          = google_bigquery_dataset.ride_sharing.dataset_id
  table_id            = "ride_requests"
  project             = var.project_id
  description         = "All ride requests with outcomes and metrics"
  deletion_protection = var.environment == "prod"

  labels = var.labels

  time_partitioning {
    type  = "DAY"
    field = "created_at"
  }

  clustering = ["state", "pickup_zone_id"]

  schema = jsonencode([
    {
      name        = "ride_request_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique ride request identifier"
    },
    {
      name        = "created_at"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "When the ride request was created"
    },
    {
      name        = "state"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Current state of the ride request"
    },
    {
      name        = "passenger_count"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Number of passengers"
    },
    {
      name        = "fare_total"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Total fare amount in USD"
    },
    {
      name        = "pickup_zone_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Pickup zone identifier"
    },
    {
      name        = "dropoff_zone_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Dropoff zone identifier"
    },
    {
      name        = "rider_gender"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Rider gender preference"
    },
    {
      name        = "driver_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Assigned driver ID"
    },
    {
      name        = "pickup_lat"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Pickup latitude"
    },
    {
      name        = "pickup_lng"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Pickup longitude"
    },
    {
      name        = "dropoff_lat"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Dropoff latitude"
    },
    {
      name        = "dropoff_lng"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Dropoff longitude"
    },
    {
      name        = "estimated_duration_seconds"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Estimated trip duration"
    },
    {
      name        = "actual_duration_seconds"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Actual trip duration"
    },
    {
      name        = "distance_km"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Trip distance in kilometers"
    },
    {
      name        = "surge_multiplier"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Surge pricing multiplier"
    },
    {
      name        = "payment_method"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Payment method used"
    },
    {
      name        = "cancelled_reason"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Reason for cancellation if applicable"
    },
    {
      name        = "completed_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "When the ride was completed"
    }
  ])
}

# Driver locations table
resource "google_bigquery_table" "driver_locations" {
  dataset_id          = google_bigquery_dataset.ride_sharing.dataset_id
  table_id            = "driver_locations"
  project             = var.project_id
  description         = "Driver location snapshots for supply analysis"
  deletion_protection = var.environment == "prod"

  labels = var.labels

  time_partitioning {
    type  = "DAY"
    field = "updated_at"
  }

  clustering = ["pickup_zone_id", "is_available"]

  schema = jsonencode([
    {
      name        = "driver_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Driver identifier"
    },
    {
      name        = "updated_at"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "When location was updated"
    },
    {
      name        = "lat"
      type        = "FLOAT"
      mode        = "REQUIRED"
      description = "Driver latitude"
    },
    {
      name        = "lng"
      type        = "FLOAT"
      mode        = "REQUIRED"
      description = "Driver longitude"
    },
    {
      name        = "pickup_zone_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Current pickup zone"
    },
    {
      name        = "is_available"
      type        = "BOOLEAN"
      mode        = "REQUIRED"
      description = "Whether driver is available for rides"
    },
    {
      name        = "active_pickups"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Number of active pickups"
    },
    {
      name        = "capacity_seats"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Vehicle seat capacity"
    }
  ])
}

# Pickup zones table
resource "google_bigquery_table" "pickup_zones" {
  dataset_id          = google_bigquery_dataset.ride_sharing.dataset_id
  table_id            = "pickup_zones"
  project             = var.project_id
  description         = "Geographic zones for pickup/dropoff aggregation"
  deletion_protection = var.environment == "prod"

  labels = var.labels

  schema = jsonencode([
    {
      name        = "zone_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Zone identifier"
    },
    {
      name        = "zone_name"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Human readable zone name"
    },
    {
      name        = "zone_lat"
      type        = "FLOAT"
      mode        = "REQUIRED"
      description = "Zone center latitude"
    },
    {
      name        = "zone_lng"
      type        = "FLOAT"
      mode        = "REQUIRED"
      description = "Zone center longitude"
    },
    {
      name        = "capacity_cars"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Maximum cars that can pickup in this zone"
    },
    {
      name        = "city"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "City name"
    },
    {
      name        = "zone_type"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Type of zone (downtown, residential, etc.)"
    },
    {
      name        = "created_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "When zone was created"
    }
  ])
}

# Hourly demand/supply aggregation table
resource "google_bigquery_table" "hourly_demand_supply" {
  dataset_id          = google_bigquery_dataset.ride_sharing.dataset_id
  table_id            = "hourly_demand_supply"
  project             = var.project_id
  description         = "Hourly aggregated demand/supply for ML model training"
  deletion_protection = var.environment == "prod"

  labels = var.labels

  time_partitioning {
    type  = "DAY"
    field = "hour_timestamp"
  }

  clustering = ["zone_id", "hour_of_day"]

  schema = jsonencode([
    {
      name        = "zone_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Zone identifier"
    },
    {
      name        = "hour_timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Hour bucket timestamp"
    },
    {
      name        = "hour_of_day"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Hour of day (0-23)"
    },
    {
      name        = "day_of_week"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Day of week (1=Sunday, 7=Saturday)"
    },
    {
      name        = "demand_count"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Number of ride requests"
    },
    {
      name        = "supply_count"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Number of available drivers"
    },
    {
      name        = "completed_rides"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Number of completed rides"
    },
    {
      name        = "avg_wait_time_seconds"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Average wait time for completed rides"
    },
    {
      name        = "surge_multiplier"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Average surge multiplier for the hour"
    }
  ])
}

# Drivers table for ML model
resource "google_bigquery_table" "drivers" {
  dataset_id          = google_bigquery_dataset.ride_sharing.dataset_id
  table_id            = "drivers"
  project             = var.project_id
  description         = "Driver profiles and capabilities"
  deletion_protection = var.environment == "prod"

  labels = var.labels

  schema = jsonencode([
    {
      name        = "driver_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Driver identifier"
    },
    {
      name        = "gender"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Driver gender"
    },
    {
      name        = "is_active"
      type        = "BOOLEAN"
      mode        = "REQUIRED"
      description = "Whether driver is active"
    },
    {
      name        = "created_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "When driver account was created"
    },
    {
      name        = "last_active_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Last time driver was active"
    }
  ])
}

# Create views and procedures using external SQL files
resource "google_bigquery_routine" "refresh_hourly_aggregation" {
  dataset_id   = google_bigquery_dataset.ride_sharing.dataset_id
  routine_id   = "refresh_hourly_aggregation"
  project      = var.project_id
  routine_type = "PROCEDURE"
  language     = "SQL"

  definition_body = file("${path.module}/../../bigquery_procedures.sql")
}

# Outputs
output "dataset_id" {
  description = "BigQuery dataset ID"
  value       = google_bigquery_dataset.ride_sharing.dataset_id
}

output "dataset_location" {
  description = "BigQuery dataset location"
  value       = google_bigquery_dataset.ride_sharing.location
}

output "tables" {
  description = "Created BigQuery tables"
  value = {
    ride_requests        = google_bigquery_table.ride_requests.table_id
    driver_locations     = google_bigquery_table.driver_locations.table_id
    pickup_zones         = google_bigquery_table.pickup_zones.table_id
    hourly_demand_supply = google_bigquery_table.hourly_demand_supply.table_id
    drivers              = google_bigquery_table.drivers.table_id
  }
} 