# Secret Manager secrets for the ride-sharing platform
# These secrets are created but not populated - values must be set manually or via CI/CD

# Slack webhook URL for notifications
resource "google_secret_manager_secret" "slack_webhook_url" {
  secret_id = "slack-webhook-url"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    component   = "notifications"
  }
}

# Mapbox access token for maps and navigation
resource "google_secret_manager_secret" "mapbox_access_token" {
  secret_id = "mapbox-access-token"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    component   = "maps"
  }
}

# Stripe secret key for payments
resource "google_secret_manager_secret" "stripe_secret_key" {
  secret_id = "stripe-secret-key"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    component   = "payments"
  }
}

# Stripe webhook secret for webhook validation
resource "google_secret_manager_secret" "stripe_webhook_secret" {
  secret_id = "stripe-webhook-secret"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    component   = "payments"
  }
}

# LiveKit API key for real-time communication
resource "google_secret_manager_secret" "livekit_api_key" {
  secret_id = "livekit-api-key"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    component   = "realtime"
  }
}

# LiveKit API secret
resource "google_secret_manager_secret" "livekit_api_secret" {
  secret_id = "livekit-api-secret"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    component   = "realtime"
  }
}

# LiveKit WebSocket URL for real-time communication
resource "google_secret_manager_secret" "livekit_ws_url" {
  secret_id = "livekit-ws-url"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    component   = "realtime"
  }
}

# Firebase service account key for admin operations
resource "google_secret_manager_secret" "firebase_service_account_key" {
  secret_id = "firebase-service-account-key"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    component   = "firebase"
  }
}

# Database encryption key for sensitive data
resource "google_secret_manager_secret" "database_encryption_key" {
  secret_id = "database-encryption-key"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    component   = "database"
  }
}

# JWT signing key for API authentication
resource "google_secret_manager_secret" "jwt_signing_key" {
  secret_id = "jwt-signing-key"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    component   = "auth"
  }
}

# IAM bindings for Cloud Functions to access secrets
resource "google_secret_manager_secret_iam_binding" "cloud_functions_access" {
  for_each = {
    slack_webhook_url            = google_secret_manager_secret.slack_webhook_url.secret_id
    mapbox_access_token          = google_secret_manager_secret.mapbox_access_token.secret_id
    stripe_secret_key            = google_secret_manager_secret.stripe_secret_key.secret_id
    stripe_webhook_secret        = google_secret_manager_secret.stripe_webhook_secret.secret_id
    livekit_api_key              = google_secret_manager_secret.livekit_api_key.secret_id
    livekit_api_secret           = google_secret_manager_secret.livekit_api_secret.secret_id
    firebase_service_account_key = google_secret_manager_secret.firebase_service_account_key.secret_id
    database_encryption_key      = google_secret_manager_secret.database_encryption_key.secret_id
    jwt_signing_key              = google_secret_manager_secret.jwt_signing_key.secret_id
  }

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"

  members = [
    "serviceAccount:${var.project_id}@appspot.gserviceaccount.com",
    "serviceAccount:cloud-functions@${var.project_id}.iam.gserviceaccount.com",
    "serviceAccount:cloud-run@${var.project_id}.iam.gserviceaccount.com"
  ]
}

# Output secret names for use in other modules
output "secret_names" {
  description = "Map of secret names for reference in other modules"
  value = {
    slack_webhook_url            = google_secret_manager_secret.slack_webhook_url.secret_id
    mapbox_access_token          = google_secret_manager_secret.mapbox_access_token.secret_id
    stripe_secret_key            = google_secret_manager_secret.stripe_secret_key.secret_id
    stripe_webhook_secret        = google_secret_manager_secret.stripe_webhook_secret.secret_id
    livekit_api_key              = google_secret_manager_secret.livekit_api_key.secret_id
    livekit_api_secret           = google_secret_manager_secret.livekit_api_secret.secret_id
    livekit_ws_url               = google_secret_manager_secret.livekit_ws_url.secret_id
    firebase_service_account_key = google_secret_manager_secret.firebase_service_account_key.secret_id
    database_encryption_key      = google_secret_manager_secret.database_encryption_key.secret_id
    jwt_signing_key              = google_secret_manager_secret.jwt_signing_key.secret_id
  }
} 