#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Liive iOS Local Development Environment${NC}"
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

# Step 1: Install dependencies
echo -e "\n${GREEN}📦 Installing backend dependencies...${NC}"
cd backend/functions
npm install
cd ../..

# Step 2: Build TypeScript functions
echo -e "\n${GREEN}🔨 Building TypeScript functions...${NC}"
cd backend/functions
npm run build
cd ../..

# Step 3: Load environment variables
echo -e "\n${GREEN}🔐 Loading environment variables...${NC}"
if [ -f "backend/functions/.env.local" ]; then
    export $(cat backend/functions/.env.local | grep -v '^#' | xargs)
    echo "Environment variables loaded"
else
    echo -e "${YELLOW}⚠️  No .env.local file found, using defaults${NC}"
fi

# Step 4: Start Firebase emulators
echo -e "\n${GREEN}🔥 Starting Firebase emulators...${NC}"
firebase emulators:start --import=./emulator-data --export-on-exit &

# Wait for emulators to start
echo -e "${YELLOW}⏳ Waiting for emulators to start...${NC}"
sleep 5

# Check if emulators are running
if curl -s http://localhost:4000 > /dev/null; then
    echo -e "${GREEN}✅ Emulators started successfully${NC}"
else
    echo -e "${YELLOW}⚠️  Emulators may still be starting...${NC}"
fi

# Step 5: Seed initial data for all features
echo -e "\n${GREEN}🌱 Seeding data for all features...${NC}"
node scripts/shared/seed-all-features.js &
SEED_PID=$!

# Wait for seeding to complete
sleep 5
kill $SEED_PID 2>/dev/null

# Step 6: Display useful information
echo -e "\n${GREEN}✨ Local environment is ready!${NC}"
echo "=================================================="
echo -e "${BLUE}📱 iOS App Configuration:${NC}"
echo "   - Firestore: localhost:8080"
echo "   - Auth: localhost:9099"
echo "   - Functions: localhost:5001"
echo ""
echo -e "${BLUE}🌐 Web UIs:${NC}"
echo "   - Emulator Suite UI: http://localhost:4000"
echo "   - Firestore: http://localhost:4000/firestore"
echo "   - Auth: http://localhost:4000/auth"
echo ""
echo -e "${BLUE}📝 Test Accounts:${NC}"
echo "   - Rider 1: rider1@example.com / testpass123"
echo "   - Rider 2: rider2@example.com / testpass123"
echo ""
echo -e "${BLUE}🚗 Test Drivers:${NC}"
echo "   - John Driver (Available)"
echo "   - Sarah Driver (Available)"
echo "   - Mike Driver (Busy)"
echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "   1. Open Xcode and run the app with Cmd+R"
echo "   2. The app will automatically connect to local emulators in DEBUG mode"
echo "   3. Use the Emulator UI to view and modify data"
echo "   4. Press Ctrl+C to stop all emulators"
echo ""
echo -e "${GREEN}🎉 Happy testing!${NC}"
echo "=================================================="

# Keep the script running
echo -e "\n${YELLOW}Press Ctrl+C to stop the emulators${NC}"
wait