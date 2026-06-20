project_id   = "liive-ride-sharing-staging"
region       = "us-central1"
environment  = "staging"

# Staging-specific configurations
enable_debug_logging = false
min_instances       = 1
max_instances       = 50
memory_limit        = "1Gi"
cpu_limit          = "2000m"

# BigQuery configurations
bigquery_location = "US"
retention_days    = 30

# Load balancer configurations
ssl_policy = "modern"
enable_cdn = true 