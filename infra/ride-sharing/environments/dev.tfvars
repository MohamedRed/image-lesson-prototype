project_id   = "liive-ride-sharing-dev"
region       = "us-central1"
environment  = "dev"

# Development-specific configurations
enable_debug_logging = true
min_instances       = 0
max_instances       = 10
memory_limit        = "512Mi"
cpu_limit          = "1000m"

# BigQuery configurations
bigquery_location = "US"
retention_days    = 7

# Load balancer configurations
ssl_policy = "modern"
enable_cdn = false 