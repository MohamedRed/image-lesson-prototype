#!/bin/bash

# Home Services Development Startup Script
# 
# This script sets up a complete development environment for the home services feature:
# - Starts Firebase emulators (Firestore, Auth, Functions)
# - Seeds test data for home services
# - Opens the emulator UI
#
# Usage: ./scripts/home-services/start-home-services-dev.sh

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏠 Starting Home Services Development Environment${NC}"
echo -e "${BLUE}=================================================${NC}"

# Check if we're in the correct directory
if [ ! -f "firebase.json" ]; then
    echo -e "${RED}❌ Error: firebase.json not found. Please run this script from the project root.${NC}"
    exit 1
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Error: Firebase CLI not installed. Please install with 'npm install -g firebase-tools'${NC}"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Error: Node.js not installed. Please install Node.js${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

# Install dependencies for scripts if needed
if [ ! -d "scripts/node_modules" ]; then
    echo -e "${YELLOW}📦 Installing script dependencies...${NC}"
    cd scripts
    npm install
    cd ..
fi

# Install Firebase Functions dependencies if needed
if [ ! -d "backend/functions/node_modules" ]; then
    echo -e "${YELLOW}📦 Installing Firebase Functions dependencies...${NC}"
    cd backend/functions
    npm install
    cd ../..
fi

echo -e "${GREEN}✅ Prerequisites check complete${NC}"

# Start Firebase emulators in background
echo -e "${YELLOW}🔥 Starting Firebase emulators...${NC}"
firebase emulators:start --only auth,firestore,functions &
FIREBASE_PID=$!

# Wait for emulators to start
echo -e "${YELLOW}⏳ Waiting for emulators to start...${NC}"
sleep 10

# Check if emulators are running
if ps -p $FIREBASE_PID > /dev/null; then
    echo -e "${GREEN}✅ Firebase emulators started successfully${NC}"
else
    echo -e "${RED}❌ Failed to start Firebase emulators${NC}"
    exit 1
fi

# Seed home services data
echo -e "${YELLOW}🌱 Seeding home services test data...${NC}"
if node scripts/home-services/seed-home-services.js; then
    echo -e "${GREEN}✅ Home services data seeded successfully${NC}"
else
    echo -e "${RED}❌ Failed to seed home services data${NC}"
    kill $FIREBASE_PID
    exit 1
fi

echo -e "${GREEN}🎉 Home Services Development Environment Ready!${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""
echo -e "${GREEN}📱 iOS App:${NC} Open image-lesson-prototype.xcodeproj in Xcode"
echo -e "${GREEN}🌐 Emulator UI:${NC} http://localhost:4000"
echo -e "${GREEN}🔥 Firestore:${NC} http://localhost:4000/firestore"
echo -e "${GREEN}🔐 Auth:${NC} http://localhost:4000/auth"
echo -e "${GREEN}⚡ Functions:${NC} http://localhost:4000/functions"
echo ""
echo -e "${YELLOW}📝 Test Data Available:${NC}"
echo -e "  • 6 service categories (plumbing, electrical, painting, etc.)"
echo -e "  • 3 professional profiles with different specializations"
echo -e "  • 2 sample RFQs ready for bidding"
echo -e "  • Test user accounts for customers and professionals"
echo ""
echo -e "${YELLOW}🧪 Testing Workflow:${NC}"
echo -e "  1. Browse service categories in the app"
echo -e "  2. Create new RFQs as a customer"
echo -e "  3. Submit bids as a professional"
echo -e "  4. Accept bids and create contracts"
echo -e "  5. Test the payment escrow system"
echo ""
echo -e "${BLUE}Press Ctrl+C to stop all services${NC}"

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
    kill $FIREBASE_PID 2>/dev/null || true
    echo -e "${GREEN}✅ Cleanup complete${NC}"
    exit 0
}

# Trap Ctrl+C and cleanup
trap cleanup INT

# Keep script running until user presses Ctrl+C
while true; do
    sleep 1
done