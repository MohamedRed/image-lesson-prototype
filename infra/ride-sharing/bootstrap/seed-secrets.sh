#!/bin/bash

# Bootstrap script to seed secrets across environments
# Usage: ./seed-secrets.sh <environment> <project-id>

set -euo pipefail

ENVIRONMENT=${1:-"dev"}
PROJECT_ID=${2:-""}
REGION=${3:-"us-central1"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [[ -z "$PROJECT_ID" ]]; then
    echo -e "${RED}Error: Project ID is required${NC}"
    echo "Usage: $0 <environment> <project-id> [region]"
    exit 1
fi

echo -e "${GREEN}🔐 Seeding secrets for environment: ${ENVIRONMENT}${NC}"
echo -e "${GREEN}📍 Project: ${PROJECT_ID}${NC}"
echo -e "${GREEN}🌍 Region: ${REGION}${NC}"

# Function to create or update a secret
create_or_update_secret() {
    local secret_name=$1
    local secret_value=$2
    local description=$3
    
    echo -e "${YELLOW}Processing secret: ${secret_name}${NC}"
    
    # Check if secret exists
    if gcloud secrets describe "$secret_name" --project="$PROJECT_ID" >/dev/null 2>&1; then
        echo "  Secret exists, adding new version..."
        echo -n "$secret_value" | gcloud secrets versions add "$secret_name" \
            --project="$PROJECT_ID" \
            --data-file=-
    else
        echo "  Creating new secret..."
        echo -n "$secret_value" | gcloud secrets create "$secret_name" \
            --project="$PROJECT_ID" \
            --data-file=- \
            --replication-policy="user-managed" \
            --locations="$REGION"
    fi
    
    echo -e "${GREEN}  ✅ ${secret_name} updated${NC}"
}

# Function to prompt for secret value
prompt_for_secret() {
    local secret_name=$1
    local description=$2
    local default_value=${3:-""}
    
    echo -e "${YELLOW}Enter value for ${secret_name}:${NC}"
    echo "  Description: $description"
    
    if [[ -n "$default_value" ]]; then
        echo "  Default: $default_value"
        read -p "  Value (press Enter for default): " -s secret_value
        echo
        if [[ -z "$secret_value" ]]; then
            secret_value="$default_value"
        fi
    else
        read -p "  Value: " -s secret_value
        echo
    fi
    
    if [[ -z "$secret_value" ]]; then
        echo -e "${RED}  Error: Secret value cannot be empty${NC}"
        return 1
    fi
    
    echo "$secret_value"
}

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 >/dev/null; then
    echo -e "${RED}Error: Not authenticated with gcloud. Run 'gcloud auth login' first.${NC}"
    exit 1
fi

# Enable Secret Manager API
echo -e "${YELLOW}Enabling Secret Manager API...${NC}"
gcloud services enable secretmanager.googleapis.com --project="$PROJECT_ID"

# Environment-specific configurations
case "$ENVIRONMENT" in
    "dev")
        SLACK_WEBHOOK_DEFAULT="https://hooks.slack.com/services/YOUR/DEV/WEBHOOK"
        MAPBOX_TOKEN_DEFAULT="pk.dev_token_here"
        STRIPE_KEY_DEFAULT="sk_test_dev_key_here"
        ;;
    "staging")
        SLACK_WEBHOOK_DEFAULT="https://hooks.slack.com/services/YOUR/STAGING/WEBHOOK"
        MAPBOX_TOKEN_DEFAULT="pk.staging_token_here"
        STRIPE_KEY_DEFAULT="sk_test_staging_key_here"
        ;;
    "prod")
        SLACK_WEBHOOK_DEFAULT=""
        MAPBOX_TOKEN_DEFAULT=""
        STRIPE_KEY_DEFAULT=""
        ;;
    *)
        echo -e "${RED}Error: Invalid environment. Must be dev, staging, or prod.${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}🚀 Starting secret seeding process...${NC}"
echo

# Slack webhook URL
SLACK_WEBHOOK=$(prompt_for_secret "slack-webhook-url" \
    "Slack webhook URL for notifications" \
    "$SLACK_WEBHOOK_DEFAULT")
create_or_update_secret "slack-webhook-url" "$SLACK_WEBHOOK" \
    "Slack webhook URL for system notifications"

# Mapbox access token
MAPBOX_TOKEN=$(prompt_for_secret "mapbox-access-token" \
    "Mapbox access token for maps and navigation" \
    "$MAPBOX_TOKEN_DEFAULT")
create_or_update_secret "mapbox-access-token" "$MAPBOX_TOKEN" \
    "Mapbox access token for maps and navigation services"

# Stripe secret key
STRIPE_SECRET=$(prompt_for_secret "stripe-secret-key" \
    "Stripe secret key for payment processing" \
    "$STRIPE_KEY_DEFAULT")
create_or_update_secret "stripe-secret-key" "$STRIPE_SECRET" \
    "Stripe secret key for payment processing"

# Stripe webhook secret
STRIPE_WEBHOOK_SECRET=$(prompt_for_secret "stripe-webhook-secret" \
    "Stripe webhook secret for webhook validation" \
    "whsec_${ENVIRONMENT}_webhook_secret")
create_or_update_secret "stripe-webhook-secret" "$STRIPE_WEBHOOK_SECRET" \
    "Stripe webhook secret for validating webhook requests"

# LiveKit API key
LIVEKIT_API_KEY=$(prompt_for_secret "livekit-api-key" \
    "LiveKit API key for real-time communication" \
    "api_key_${ENVIRONMENT}")
create_or_update_secret "livekit-api-key" "$LIVEKIT_API_KEY" \
    "LiveKit API key for real-time communication services"

# LiveKit API secret
LIVEKIT_API_SECRET=$(prompt_for_secret "livekit-api-secret" \
    "LiveKit API secret for real-time communication" \
    "api_secret_${ENVIRONMENT}")
create_or_update_secret "livekit-api-secret" "$LIVEKIT_API_SECRET" \
    "LiveKit API secret for real-time communication services"

# LiveKit WebSocket URL
LIVEKIT_WS_URL=$(prompt_for_secret "livekit-ws-url" \
    "LiveKit WebSocket URL for real-time communication" \
    "wss://live-${ENVIRONMENT}.example.com")
create_or_update_secret "livekit-ws-url" "$LIVEKIT_WS_URL" \
    "LiveKit WebSocket URL for real-time communication services"

# Generate Firebase service account key (if not exists)
SA_EMAIL="firebase-admin@${PROJECT_ID}.iam.gserviceaccount.com"
echo -e "${YELLOW}Checking Firebase service account...${NC}"

if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "  Creating Firebase service account..."
    gcloud iam service-accounts create firebase-admin \
        --project="$PROJECT_ID" \
        --display-name="Firebase Admin Service Account" \
        --description="Service account for Firebase admin operations"
    
    # Grant necessary roles
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/firebase.admin"
fi

# Generate service account key
echo "  Generating service account key..."
SA_KEY=$(gcloud iam service-accounts keys create /dev/stdout \
    --iam-account="$SA_EMAIL" \
    --project="$PROJECT_ID" \
    --key-file-type="json")

create_or_update_secret "firebase-service-account-key" "$SA_KEY" \
    "Firebase service account key for admin operations"

# Generate database encryption key
DB_ENCRYPTION_KEY=$(openssl rand -base64 32)
create_or_update_secret "database-encryption-key" "$DB_ENCRYPTION_KEY" \
    "Database encryption key for sensitive data"

# Generate JWT signing key
JWT_SIGNING_KEY=$(openssl rand -base64 64)
create_or_update_secret "jwt-signing-key" "$JWT_SIGNING_KEY" \
    "JWT signing key for API authentication"

echo
echo -e "${GREEN}✅ Secret seeding completed successfully!${NC}"
echo
echo -e "${YELLOW}📋 Summary of secrets created/updated:${NC}"
echo "  • slack-webhook-url"
echo "  • mapbox-access-token"
echo "  • stripe-secret-key"
echo "  • stripe-webhook-secret"
echo "  • livekit-api-key"
echo "  • livekit-api-secret"
echo "  • firebase-service-account-key"
echo "  • database-encryption-key"
echo "  • jwt-signing-key"
echo
echo -e "${YELLOW}🔧 Next steps:${NC}"
echo "  1. Run terraform plan/apply to create secret resources"
echo "  2. Verify Cloud Functions have access to secrets"
echo "  3. Test secret access in your application"
echo
echo -e "${GREEN}🎉 Bootstrap complete!${NC}" 