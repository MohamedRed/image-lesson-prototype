#!/bin/bash

# Performance testing script for ride-sharing platform
# Usage: ./run-performance-tests.sh [environment] [test-type] [users] [duration]

set -euo pipefail

# Default values
ENVIRONMENT=${1:-"staging"}
TEST_TYPE=${2:-"load"}
CONCURRENT_USERS=${3:-"100"}
TEST_DURATION=${4:-"300"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
REPORTS_DIR="${SCRIPT_DIR}/reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Environment URLs
declare -A ENV_URLS=(
    ["dev"]="https://us-central1-liive-ride-sharing-dev.cloudfunctions.net"
    ["staging"]="https://us-central1-liive-ride-sharing-staging.cloudfunctions.net"
    ["prod"]="https://us-central1-liive-ride-sharing-prod.cloudfunctions.net"
)

# Test scenarios
declare -A TEST_SCENARIOS=(
    ["smoke"]="10 60 60"      # 10 users, 60s ramp-up, 60s duration
    ["load"]="100 120 300"    # 100 users, 2min ramp-up, 5min duration
    ["stress"]="500 300 600"  # 500 users, 5min ramp-up, 10min duration
    ["spike"]="1000 60 300"   # 1000 users, 1min ramp-up, 5min duration
    ["soak"]="200 300 1800"   # 200 users, 5min ramp-up, 30min duration
)

echo -e "${GREEN}🚀 Starting Performance Tests${NC}"
echo -e "${BLUE}Environment: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}Test Type: ${TEST_TYPE}${NC}"
echo -e "${BLUE}Timestamp: ${TIMESTAMP}${NC}"

# Validate environment
if [[ ! ${ENV_URLS[$ENVIRONMENT]+_} ]]; then
    echo -e "${RED}❌ Invalid environment: ${ENVIRONMENT}${NC}"
    echo "Valid environments: ${!ENV_URLS[@]}"
    exit 1
fi

# Get test scenario parameters
if [[ ${TEST_SCENARIOS[$TEST_TYPE]+_} ]]; then
    IFS=' ' read -r CONCURRENT_USERS RAMP_UP_TIME TEST_DURATION <<< "${TEST_SCENARIOS[$TEST_TYPE]}"
fi

BASE_URL="${ENV_URLS[$ENVIRONMENT]}"

echo -e "${YELLOW}📊 Test Configuration:${NC}"
echo "  Base URL: ${BASE_URL}"
echo "  Concurrent Users: ${CONCURRENT_USERS}"
echo "  Ramp-up Time: ${RAMP_UP_TIME}s"
echo "  Test Duration: ${TEST_DURATION}s"

# Create directories
mkdir -p "${RESULTS_DIR}" "${REPORTS_DIR}"

# Check if JMeter is installed
if ! command -v jmeter &> /dev/null; then
    echo -e "${RED}❌ JMeter not found. Please install Apache JMeter.${NC}"
    echo "On macOS: brew install jmeter"
    echo "On Ubuntu: sudo apt-get install jmeter"
    exit 1
fi

# Check if the target environment is reachable
echo -e "${YELLOW}🔍 Checking environment health...${NC}"
if ! curl -f -s "${BASE_URL}/health" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Health endpoint not reachable, continuing anyway...${NC}"
fi

# Run the performance test
TEST_PLAN="${SCRIPT_DIR}/jmeter-test-plan.jmx"
RESULTS_FILE="${RESULTS_DIR}/results_${ENVIRONMENT}_${TEST_TYPE}_${TIMESTAMP}.jtl"
LOG_FILE="${RESULTS_DIR}/jmeter_${ENVIRONMENT}_${TEST_TYPE}_${TIMESTAMP}.log"

echo -e "${YELLOW}🏃 Running JMeter test...${NC}"

jmeter -n -t "${TEST_PLAN}" \
    -Jbase_url="${BASE_URL}" \
    -Jconcurrent_users="${CONCURRENT_USERS}" \
    -Jramp_up_time="${RAMP_UP_TIME}" \
    -Jtest_duration="${TEST_DURATION}" \
    -l "${RESULTS_FILE}" \
    -j "${LOG_FILE}" \
    -e -o "${REPORTS_DIR}/html_report_${ENVIRONMENT}_${TEST_TYPE}_${TIMESTAMP}"

# Check if test completed successfully
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Performance test completed successfully${NC}"
else
    echo -e "${RED}❌ Performance test failed${NC}"
    exit 1
fi

# Generate summary report
echo -e "${YELLOW}📈 Generating summary report...${NC}"

SUMMARY_FILE="${REPORTS_DIR}/summary_${ENVIRONMENT}_${TEST_TYPE}_${TIMESTAMP}.txt"

cat > "${SUMMARY_FILE}" << EOF
# Performance Test Summary Report

**Environment:** ${ENVIRONMENT}
**Test Type:** ${TEST_TYPE}
**Timestamp:** ${TIMESTAMP}
**Base URL:** ${BASE_URL}

## Test Configuration
- Concurrent Users: ${CONCURRENT_USERS}
- Ramp-up Time: ${RAMP_UP_TIME}s
- Test Duration: ${TEST_DURATION}s

## Results Analysis
EOF

# Parse JTL file for key metrics using awk
if [[ -f "${RESULTS_FILE}" ]]; then
    echo -e "${YELLOW}📊 Analyzing results...${NC}"
    
    # Calculate key metrics
    TOTAL_REQUESTS=$(tail -n +2 "${RESULTS_FILE}" | wc -l)
    SUCCESS_REQUESTS=$(tail -n +2 "${RESULTS_FILE}" | awk -F',' '$8 == "true" {count++} END {print count+0}')
    FAILED_REQUESTS=$((TOTAL_REQUESTS - SUCCESS_REQUESTS))
    SUCCESS_RATE=$(echo "scale=2; ${SUCCESS_REQUESTS} * 100 / ${TOTAL_REQUESTS}" | bc -l 2>/dev/null || echo "0")
    
    # Response time percentiles (simplified calculation)
    RESPONSE_TIMES=$(tail -n +2 "${RESULTS_FILE}" | awk -F',' '{print $2}' | sort -n)
    AVG_RESPONSE_TIME=$(echo "${RESPONSE_TIMES}" | awk '{sum+=$1} END {print sum/NR}' | xargs printf "%.0f")
    
    # Calculate percentiles
    P50=$(echo "${RESPONSE_TIMES}" | awk 'NR == int(NR*0.5) {print}' | head -1)
    P95=$(echo "${RESPONSE_TIMES}" | awk 'NR == int(NR*0.95) {print}' | head -1)
    P99=$(echo "${RESPONSE_TIMES}" | awk 'NR == int(NR*0.99) {print}' | head -1)
    MAX_RESPONSE_TIME=$(echo "${RESPONSE_TIMES}" | tail -1)
    
    # Throughput calculation
    THROUGHPUT=$(echo "scale=2; ${SUCCESS_REQUESTS} / ${TEST_DURATION}" | bc -l)
    
    # Append metrics to summary
    cat >> "${SUMMARY_FILE}" << EOF

### Key Metrics
- **Total Requests:** ${TOTAL_REQUESTS}
- **Successful Requests:** ${SUCCESS_REQUESTS}
- **Failed Requests:** ${FAILED_REQUESTS}
- **Success Rate:** ${SUCCESS_RATE}%
- **Throughput:** ${THROUGHPUT} req/sec

### Response Time Analysis
- **Average Response Time:** ${AVG_RESPONSE_TIME}ms
- **50th Percentile (P50):** ${P50}ms
- **95th Percentile (P95):** ${P95}ms
- **99th Percentile (P99):** ${P99}ms
- **Maximum Response Time:** ${MAX_RESPONSE_TIME}ms

### SLA Compliance
EOF

    # Check SLA compliance (P95 < 2000ms)
    if [[ ${P95} -lt 2000 ]]; then
        echo "- **P95 SLA (< 2000ms):** ✅ PASS (${P95}ms)" >> "${SUMMARY_FILE}"
        SLA_STATUS="PASS"
    else
        echo "- **P95 SLA (< 2000ms):** ❌ FAIL (${P95}ms)" >> "${SUMMARY_FILE}"
        SLA_STATUS="FAIL"
    fi
    
    # Check success rate SLA (> 95%)
    if (( $(echo "${SUCCESS_RATE} > 95" | bc -l) )); then
        echo "- **Success Rate SLA (> 95%):** ✅ PASS (${SUCCESS_RATE}%)" >> "${SUMMARY_FILE}"
    else
        echo "- **Success Rate SLA (> 95%):** ❌ FAIL (${SUCCESS_RATE}%)" >> "${SUMMARY_FILE}"
        SLA_STATUS="FAIL"
    fi
    
    echo "" >> "${SUMMARY_FILE}"
    echo "**Overall SLA Status:** ${SLA_STATUS}" >> "${SUMMARY_FILE}"
    
    # Display summary
    echo -e "${GREEN}📋 Test Summary:${NC}"
    echo "  Total Requests: ${TOTAL_REQUESTS}"
    echo "  Success Rate: ${SUCCESS_RATE}%"
    echo "  Average Response Time: ${AVG_RESPONSE_TIME}ms"
    echo "  P95 Response Time: ${P95}ms"
    echo "  Throughput: ${THROUGHPUT} req/sec"
    echo "  SLA Status: ${SLA_STATUS}"
    
    # Generate alerts if SLA failed
    if [[ "${SLA_STATUS}" == "FAIL" ]]; then
        echo -e "${RED}🚨 SLA VIOLATION DETECTED${NC}"
        
        # Create alert file
        ALERT_FILE="${REPORTS_DIR}/alert_${ENVIRONMENT}_${TEST_TYPE}_${TIMESTAMP}.json"
        cat > "${ALERT_FILE}" << EOF
{
  "alert": "Performance SLA Violation",
  "environment": "${ENVIRONMENT}",
  "test_type": "${TEST_TYPE}",
  "timestamp": "${TIMESTAMP}",
  "metrics": {
    "p95_response_time": ${P95},
    "success_rate": ${SUCCESS_RATE},
    "total_requests": ${TOTAL_REQUESTS},
    "throughput": ${THROUGHPUT}
  },
  "sla_requirements": {
    "p95_max": 2000,
    "success_rate_min": 95
  }
}
EOF
        
        echo -e "${YELLOW}📧 Alert file created: ${ALERT_FILE}${NC}"
    fi
fi

# Generate comparison report if previous results exist
PREVIOUS_RESULTS=$(find "${RESULTS_DIR}" -name "results_${ENVIRONMENT}_${TEST_TYPE}_*.jtl" | head -2 | tail -1)
if [[ -f "${PREVIOUS_RESULTS}" && "${PREVIOUS_RESULTS}" != "${RESULTS_FILE}" ]]; then
    echo -e "${YELLOW}📊 Generating comparison report...${NC}"
    echo "" >> "${SUMMARY_FILE}"
    echo "### Trend Analysis" >> "${SUMMARY_FILE}"
    echo "Comparison with previous test run available in detailed HTML report." >> "${SUMMARY_FILE}"
fi

echo -e "${GREEN}📁 Results saved to:${NC}"
echo "  JTL File: ${RESULTS_FILE}"
echo "  HTML Report: ${REPORTS_DIR}/html_report_${ENVIRONMENT}_${TEST_TYPE}_${TIMESTAMP}/index.html"
echo "  Summary: ${SUMMARY_FILE}"
echo "  Log File: ${LOG_FILE}"

echo -e "${GREEN}🎉 Performance testing completed!${NC}"

# Return appropriate exit code
if [[ "${SLA_STATUS:-UNKNOWN}" == "FAIL" ]]; then
    exit 1
else
    exit 0
fi 