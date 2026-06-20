#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Liive iOS Full Local Development Stack${NC}"
echo "======================================================="

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running${NC}"
    echo "Please start Docker Desktop and try again"
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not available${NC}"
    echo "Please install Docker Compose and try again"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ Not in project root directory${NC}"
    echo "Please run this script from the liive-ios directory"
    exit 1
fi

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}🛑 Shutting down full local stack...${NC}"
    docker compose down
    exit 0
}

# Trap Ctrl+C and cleanup
trap cleanup INT

# Load environment variables from backend functions
echo -e "\n${GREEN}🔐 Loading environment variables...${NC}"
if [ -f "backend/functions/.env.local" ]; then
    export $(cat backend/functions/.env.local | grep -v '^#' | xargs)
    echo "Environment variables loaded from backend/functions/.env.local"
else
    echo -e "${YELLOW}⚠️  No .env.local file found${NC}"
    echo "Please create backend/functions/.env.local with your test keys"
    exit 1
fi

# Verify critical environment variables
echo -e "\n${GREEN}✅ Verifying external service configuration...${NC}"
if [[ $STRIPE_SECRET_KEY == sk_test_* ]]; then
    echo "✅ Stripe: Using test keys"
else
    echo -e "${YELLOW}⚠️  Stripe: No test key found or not in test mode${NC}"
fi

if [[ $RADAR_SECRET_KEY == prj_test_* ]]; then
    echo "✅ Radar: Using test keys"
else
    echo -e "${YELLOW}⚠️  Radar: No test key found or not in test mode${NC}"
fi

if [[ $LIVEKIT_URL == wss://* ]]; then
    echo "✅ LiveKit: Using cloud instance"
else
    echo -e "${YELLOW}⚠️  LiveKit: No cloud URL configured${NC}"
fi

# Build and start the full stack
echo -e "\n${GREEN}🐳 Building and starting Docker containers...${NC}"
docker compose up --build -d

# Wait for services to start
echo -e "\n${YELLOW}⏳ Waiting for services to start...${NC}"
sleep 10

# Check service health
echo -e "\n${GREEN}🔍 Checking service health...${NC}"

# Check Firebase Emulators
if curl -s http://localhost:4000 > /dev/null; then
    echo "✅ Firebase Emulators UI: http://localhost:4000"
else
    echo -e "${YELLOW}⚠️  Firebase Emulators: Starting up...${NC}"
fi

# Check Firestore
if curl -s http://localhost:8080 > /dev/null; then
    echo "✅ Firestore Emulator: localhost:8080"
else
    echo -e "${YELLOW}⚠️  Firestore: Starting up...${NC}"
fi

# Check Go Planner
if curl -s http://localhost:8081/health > /dev/null; then
    echo "✅ Go Planner Service: http://localhost:8081"
else
    echo -e "${YELLOW}⚠️  Go Planner: Starting up...${NC}"
fi

# Check BigQuery CLI
if docker compose exec -T bigquery-cli gcloud --version > /dev/null; then
    echo "✅ BigQuery CLI: Ready for test dataset operations"
else
    echo -e "${YELLOW}⚠️  BigQuery CLI: Starting up...${NC}"
fi

# Check PubSub Emulator
if curl -s http://localhost:8085 > /dev/null; then
    echo "✅ PubSub Emulator: localhost:8085"
else
    echo -e "${YELLOW}⚠️  PubSub Emulator: Starting up...${NC}"
fi


# Seed initial data
echo -e "\n${GREEN}🌱 Seeding initial data...${NC}"
sleep 5
node scripts/shared/seed-all-features.js &
SEED_PID=$!
sleep 3
kill $SEED_PID 2>/dev/null

# Display comprehensive service information
echo -e "\n${GREEN}✨ Full Local Development Stack is ready!${NC}"
echo "======================================================="

echo -e "\n${BLUE}🏗️  Core Infrastructure:${NC}"
echo "   - Firebase Emulators UI: http://localhost:4000"
echo "   - Firestore: localhost:8080"
echo "   - Auth: localhost:9099"
echo "   - Functions: localhost:5001"

echo -e "\n${BLUE}🚀 Backend Services:${NC}"
echo "   - Go Planner API: http://localhost:8081"
echo "   - BigQuery: Real cloud instance with test dataset"
echo "   - PubSub Emulator: localhost:8085"

echo -e "\n${BLUE}🔧 External Services (Test Mode):${NC}"
echo "   - Stripe: Using test keys (sk_test_*)"
echo "   - Radar: Using test keys (prj_test_*)"
echo "   - LiveKit: Using cloud instance ($LIVEKIT_URL)"
echo "   - Mapbox: Using test token"

echo -e "\n${BLUE}📊 Monitoring & Observability:${NC}"
echo "   - Grafana Dashboard: http://localhost:3000 (admin/admin)"
echo "   - Prometheus Metrics: http://localhost:9090"

echo -e "\n${BLUE}📱 iOS App Configuration:${NC}"
echo "   Use: RideMapContainerView(mode: .localDev(.default))"
echo "   The app will connect to all local services automatically"

echo -e "\n${BLUE}🔧 Useful Docker Commands:${NC}"
echo "   - View logs: docker compose logs -f [service_name]"
echo "   - Restart service: docker compose restart [service_name]"
echo "   - Stop all: docker compose down"

echo -e "\n${YELLOW}💡 External Service Testing:${NC}"
echo "   1. Stripe webhooks are forwarded via Stripe CLI"
echo "   2. Radar events use real test API endpoints"
echo "   3. LiveKit rooms are created in your cloud instance"
echo "   4. All payments use Stripe test mode"

echo -e "\n${YELLOW}Press Ctrl+C to stop the full stack${NC}"
echo "======================================================="

# Keep the script running and show live logs
echo -e "\n${GREEN}📊 Live service logs:${NC}"
docker compose logs -f --tail=20