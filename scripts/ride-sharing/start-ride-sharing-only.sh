#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚗 Starting Ride-Sharing Feature Only${NC}"
echo "=================================================="

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI is not installed${NC}"
    echo "Please install it with: npm install -g firebase-tools"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "firebase.json" ]; then
    echo -e "${RED}❌ Not in project root directory${NC}"
    echo "Please run this script from the liive-ios directory"
    exit 1
fi

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}🛑 Shutting down emulators...${NC}"
    pkill -f "firebase emulators"
    exit 0
}

# Trap Ctrl+C and cleanup
trap cleanup INT

# Step 1: Install dependencies and build functions
echo -e "\n${GREEN}📦 Setting up backend...${NC}"
cd backend/functions
npm install
npm run build
cd ../..

# Step 2: Load environment variables
echo -e "\n${GREEN}🔐 Loading environment variables...${NC}"
if [ -f "backend/functions/.env.local" ]; then
    export $(cat backend/functions/.env.local | grep -v '^#' | xargs)
    echo "Environment variables loaded"
else
    echo -e "${YELLOW}⚠️  No .env.local file found, using defaults${NC}"
fi

# Step 3: Start Firebase emulators
echo -e "\n${GREEN}🔥 Starting Firebase emulators...${NC}"
firebase emulators:start --import=./emulator-data --export-on-exit &

# Wait for emulators to start
echo -e "${YELLOW}⏳ Waiting for emulators to start...${NC}"
sleep 5

# Step 4: Seed only ride-sharing data
echo -e "\n${GREEN}🚗 Seeding ride-sharing data only...${NC}"
node scripts/ride-sharing/seed-riders-drivers.js &
SEED_PID=$!

# Wait for seeding to complete
sleep 5
kill $SEED_PID 2>/dev/null

# Display information
echo -e "\n${GREEN}✨ Ride-sharing environment is ready!${NC}"
echo "=================================================="
echo -e "${BLUE}📱 iOS App Configuration:${NC}"
echo "   - Firestore: localhost:8080"
echo "   - Auth: localhost:9099"
echo "   - Functions: localhost:5001"
echo ""
echo -e "${BLUE}🌐 Web UIs:${NC}"
echo "   - Emulator Suite UI: http://localhost:4000"
echo "   - Firestore: http://localhost:4000/firestore"
echo ""
echo -e "${BLUE}🚗 Test Data Available:${NC}"
echo "   - 3 drivers (John, Sarah, Mike)"
echo "   - 2 riders (Alice, Bob)" 
echo "   - 3 pickup zones in SF"
echo ""
echo -e "${YELLOW}💡 Testing:${NC}"
echo "   1. Open Xcode and run the app"
echo "   2. Navigate to Ride Sharing feature"
echo "   3. Toggle 'Live Mode' in settings to test with real data"
echo ""
echo -e "${GREEN}🎉 Ready to test ride-sharing!${NC}"
echo "=================================================="

# Keep the script running
echo -e "\n${YELLOW}Press Ctrl+C to stop the emulators${NC}"
wait