#!/bin/bash

# Bootstrap script to set up Terraform remote backend
# This script creates the GCS bucket for storing Terraform state
# Usage: ./setup-terraform-backend.sh <project-id> [bucket-name] [region]

set -euo pipefail

PROJECT_ID=${1:-""}
BUCKET_NAME=${2:-"liive-terraform-state"}
REGION=${3:-"us-central1"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [[ -z "$PROJECT_ID" ]]; then
    echo -e "${RED}Error: Project ID is required${NC}"
    echo "Usage: $0 <project-id> [bucket-name] [region]"
    exit 1
fi

echo -e "${GREEN}🚀 Setting up Terraform remote backend${NC}"
echo -e "${GREEN}📍 Project: ${PROJECT_ID}${NC}"
echo -e "${GREEN}🪣 Bucket: ${BUCKET_NAME}${NC}"
echo -e "${GREEN}🌍 Region: ${REGION}${NC}"

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 >/dev/null; then
    echo -e "${RED}Error: Not authenticated with gcloud. Run 'gcloud auth login' first.${NC}"
    exit 1
fi

# Set the project
gcloud config set project "$PROJECT_ID"

# Enable required APIs
echo -e "${YELLOW}Enabling required APIs...${NC}"
gcloud services enable \
    storage-api.googleapis.com \
    storage-component.googleapis.com \
    cloudbuild.googleapis.com \
    --project="$PROJECT_ID"

# Check if bucket already exists
if gsutil ls -p "$PROJECT_ID" "gs://${BUCKET_NAME}" >/dev/null 2>&1; then
    echo -e "${YELLOW}Bucket gs://${BUCKET_NAME} already exists${NC}"
else
    # Create the bucket
    echo -e "${YELLOW}Creating GCS bucket for Terraform state...${NC}"
    gsutil mb -p "$PROJECT_ID" -c "STANDARD" -l "$REGION" "gs://${BUCKET_NAME}"
    echo -e "${GREEN}✅ Bucket created: gs://${BUCKET_NAME}${NC}"
fi

# Enable versioning for state locking
echo -e "${YELLOW}Enabling versioning on bucket...${NC}"
gsutil versioning set on "gs://${BUCKET_NAME}"

# Set bucket lifecycle to clean up old versions
echo -e "${YELLOW}Setting up lifecycle policy...${NC}"
cat > /tmp/lifecycle.json << 'EOF'
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "age": 30,
          "isLive": false
        }
      }
    ]
  }
}
EOF

gsutil lifecycle set /tmp/lifecycle.json "gs://${BUCKET_NAME}"
rm /tmp/lifecycle.json

# Set IAM permissions for Terraform service account
echo -e "${YELLOW}Setting up IAM permissions...${NC}"

# Create Terraform service account if it doesn't exist
TF_SA_EMAIL="terraform@${PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe "$TF_SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "  Creating Terraform service account..."
    gcloud iam service-accounts create terraform \
        --project="$PROJECT_ID" \
        --display-name="Terraform Service Account" \
        --description="Service account for Terraform operations"
    
    # Grant necessary roles
    echo "  Granting IAM roles..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$TF_SA_EMAIL" \
        --role="roles/editor"
    
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$TF_SA_EMAIL" \
        --role="roles/storage.admin"
    
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$TF_SA_EMAIL" \
        --role="roles/cloudsql.admin"
    
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$TF_SA_EMAIL" \
        --role="roles/compute.admin"
else
    echo "  Terraform service account already exists"
fi

# Grant bucket access to the service account
gsutil iam ch "serviceAccount:${TF_SA_EMAIL}:objectAdmin" "gs://${BUCKET_NAME}"
gsutil iam ch "serviceAccount:${TF_SA_EMAIL}:legacyBucketReader" "gs://${BUCKET_NAME}"

# Grant bucket access to Cloud Build service account for CI/CD
CB_SA_EMAIL="${PROJECT_ID}@cloudbuild.gserviceaccount.com"
gsutil iam ch "serviceAccount:${CB_SA_EMAIL}:objectAdmin" "gs://${BUCKET_NAME}"
gsutil iam ch "serviceAccount:${CB_SA_EMAIL}:legacyBucketReader" "gs://${BUCKET_NAME}"

# Create service account key for GitHub Actions
echo -e "${YELLOW}Creating service account key for GitHub Actions...${NC}"
SA_KEY_FILE="terraform-sa-key.json"

if [[ -f "$SA_KEY_FILE" ]]; then
    echo "  Service account key file already exists: $SA_KEY_FILE"
    echo -e "${YELLOW}  Remove it if you want to generate a new one${NC}"
else
    gcloud iam service-accounts keys create "$SA_KEY_FILE" \
        --iam-account="$TF_SA_EMAIL" \
        --project="$PROJECT_ID"
    
    echo -e "${GREEN}✅ Service account key created: $SA_KEY_FILE${NC}"
    echo -e "${YELLOW}⚠️  Add this key to GitHub Secrets as GCP_SA_KEY${NC}"
fi

# Test backend access
echo -e "${YELLOW}Testing backend access...${NC}"
echo "terraform { backend \"gcs\" { bucket = \"${BUCKET_NAME}\" } }" > /tmp/test-backend.tf
cd /tmp
terraform init -backend-config="bucket=${BUCKET_NAME}" -backend-config="prefix=test" >/dev/null 2>&1 || {
    echo -e "${RED}❌ Backend test failed${NC}"
    exit 1
}
rm -rf .terraform .terraform.lock.hcl test-backend.tf
cd - >/dev/null

echo
echo -e "${GREEN}✅ Terraform remote backend setup completed!${NC}"
echo
echo -e "${YELLOW}📋 Summary:${NC}"
echo "  • Bucket: gs://${BUCKET_NAME}"
echo "  • Versioning: Enabled"
echo "  • Lifecycle: 30-day cleanup for old versions"
echo "  • Service Account: $TF_SA_EMAIL"
echo "  • IAM Permissions: Configured"
echo
echo -e "${YELLOW}🔧 Next steps:${NC}"
echo "  1. Add $SA_KEY_FILE contents to GitHub Secrets as GCP_SA_KEY"
echo "  2. Update backend.tf with the correct bucket name"
echo "  3. Run 'terraform init' to migrate to remote backend"
echo "  4. Commit and push your changes"
echo
echo -e "${GREEN}🎉 Backend setup complete!${NC}" 