project_id  = "liive-ride-sharing-prod"
region      = "us-central1"
environment = "prod"

# Production-specific configurations
enable_debug_logging = false
min_instances        = 5
max_instances        = 100
memory_limit         = "2Gi"
cpu_limit            = "4000m"

# BigQuery configurations
bigquery_location = "US"
retention_days    = 30

# Load balancer configurations
ssl_policy = "restricted"
enable_cdn = true

# High availability settings
enable_multi_region   = true
backup_retention_days = 90 