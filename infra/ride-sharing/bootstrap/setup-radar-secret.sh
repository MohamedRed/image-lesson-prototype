#!/bin/bash

# Setup script to add Radar publishable key to Google Cloud Secret Manager

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Radar publishable key in Secret Manager...${NC}"

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo "Please install gcloud CLI: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Get current project
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: No Google Cloud project configured${NC}"
    echo "Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo -e "${YELLOW}Using project: ${PROJECT_ID}${NC}"

# Prompt for Radar publishable key
echo ""
echo -e "${YELLOW}Enter your Radar publishable key:${NC}"
echo "You can find this in your Radar dashboard at https://radar.com/dashboard"
echo "The key should start with 'prj_test_' or 'prj_live_'"
read -s RADAR_KEY

if [ -z "$RADAR_KEY" ]; then
    echo -e "${RED}Error: Radar publishable key cannot be empty${NC}"
    exit 1
fi

# Validate key format
if [[ ! "$RADAR_KEY" =~ ^prj_(test|live)_ ]]; then
    echo -e "${YELLOW}Warning: Key doesn't match expected format (prj_test_* or prj_live_*)${NC}"
    echo "Continue anyway? (y/N)"
    read -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 1
    fi
fi

# Create or update the secret
SECRET_NAME="radar-publishable-key"

echo -e "${GREEN}Creating/updating secret: ${SECRET_NAME}${NC}"

if gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" &>/dev/null; then
    echo "Secret already exists, adding new version..."
    echo -n "$RADAR_KEY" | gcloud secrets versions add "$SECRET_NAME" --data-file=- --project="$PROJECT_ID"
else
    echo "Creating new secret..."
    echo -n "$RADAR_KEY" | gcloud secrets create "$SECRET_NAME" --data-file=- --project="$PROJECT_ID"
fi

# Grant access to Cloud Functions service account
CLOUD_FUNCTIONS_SA="${PROJECT_ID}@appspot.gserviceaccount.com"

echo -e "${GREEN}Granting access to Cloud Functions service account...${NC}"
gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
    --member="serviceAccount:${CLOUD_FUNCTIONS_SA}" \
    --role="roles/secretmanager.secretAccessor" \
    --project="$PROJECT_ID"

echo ""
echo -e "${GREEN}✅ Radar publishable key setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Deploy your Cloud Functions: cd backend/functions && firebase deploy --only functions"
echo "2. Your iOS app will now automatically fetch the Radar key from /config endpoint"
echo ""
echo "To test the config endpoint:"
echo "curl https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/config"