# Ride Sharing Platform - Run Book

> On-call procedures, monitoring dashboards, and escalation protocols.

---

## 🚨 Emergency Contacts

| Role | Contact | Phone | Slack |
|------|---------|-------|-------|
| Engineering Lead | John Smith | +1-555-0101 | @john.smith |
| DevOps Engineer | Jane Doe | +1-555-0102 | @jane.doe |
| Product Manager | Mike Johnson | +1-555-0103 | @mike.johnson |
| CEO | Sarah Wilson | +1-555-0100 | @sarah.wilson |

**Emergency Escalation**: If platform is completely down, call Engineering Lead first, then DevOps Engineer.

---

## 🛣️ Multi-Hop Journey Monitoring

### Key Multi-Hop Metrics

| Metric | Target | Alert Threshold | Action |
|--------|--------|-----------------|--------|
| Multi-hop success rate | >85% | <75% | Check transfer point availability |
| Average planning time | <3s | >5s | Scale planner service |
| Resource reservation failures | <5% | >10% | Review driver availability |
| Transfer point congestion | <2.0 factor | >3.0 factor | Add curb capacity |
| Gender pool violations | 0% | >1% | Investigate driver pool balance |

### Multi-Hop Alerts

#### Critical Alerts
- **Multi-hop planner down**: Immediate page, fallback to single-hop only
- **Transfer point database corruption**: Page engineering lead
- **Mass multi-leg reservation failures**: Check resource calculation logic

#### Warning Alerts  
- **High multi-hop planning latency**: Scale Cloud Run instances
- **Low transfer point availability**: Review curb segment data
- **Gender pool imbalance**: Notify operations for driver recruitment

### Troubleshooting Multi-Hop Issues

1. **Check planner service health**:
   ```bash
   curl https://planner-service-url/health
   ```

2. **Validate transfer point data**:
   ```sql
   SELECT COUNT(*) FROM curbSegments 
   WHERE allowedUses CONTAINS 'passenger-pickup' 
   AND geometry IS NOT NULL;
   ```

3. **Monitor resource reservation patterns**:
   ```sql
   SELECT 
     DATE(timestamp) as date,
     COUNT(*) as multi_leg_reservations,
     AVG(array_length(legs)) as avg_legs
   FROM reserveMultiLegResources
   WHERE timestamp >= CURRENT_DATE - 7
   GROUP BY date
   ORDER BY date DESC;
   ```

---

## 📊 Key Dashboards

### Primary Dashboard
- **URL**: `https://console.cloud.google.com/monitoring/dashboards/custom/{dashboard_id}`
- **Purpose**: Real-time platform health overview
- **Key Metrics**:
  - Active rides count
  - Driver utilization rate
  - Function execution times
  - Error rates

### Business Metrics Dashboard
- **URL**: `https://console.cloud.google.com/monitoring/dashboards/custom/{business_dashboard_id}`
- **Purpose**: Business KPIs and revenue tracking
- **Key Metrics**:
  - Ride completion rate
  - Revenue per hour
  - Driver earnings
  - Customer satisfaction

### Security Dashboard
- **URL**: `https://console.cloud.google.com/monitoring/dashboards/custom/{security_dashboard_id}`
- **Purpose**: Fraud detection and security monitoring
- **Key Metrics**:
  - Location spoofing alerts
  - Inventory mismatches
  - Failed authentication attempts
  - Suspicious activity patterns

### Multi-Hop Journey Dashboard
- **URL**: `https://console.cloud.google.com/monitoring/dashboards/custom/{multihop_dashboard_id}`
- **Purpose**: Monitor complex multi-leg journey performance
- **Key Metrics**:
  - Multi-hop success rate (target: >85%)
  - Average legs per journey
  - Transfer point utilization
  - Multi-leg resource reservation failures
  - Gender pool consistency violations
  - Journey completion times by leg count

---

## 🔥 Incident Response Procedures

### Severity Levels

#### P0 - Critical (Platform Down)
- **Definition**: Complete platform outage, no rides can be requested
- **Response Time**: 15 minutes
- **Escalation**: Immediately notify Engineering Lead and CEO
- **Examples**:
  - Firestore completely unavailable
  - All Cloud Functions failing
  - Authentication system down

#### P1 - High (Major Feature Broken)
- **Definition**: Core functionality impacted, significant user impact
- **Response Time**: 1 hour
- **Escalation**: Notify Engineering Lead within 30 minutes
- **Examples**:
  - Ride matching completely failing
  - Payment processing down
  - LiveKit audio/video not working

#### P2 - Medium (Degraded Performance)
- **Definition**: Platform working but with reduced performance
- **Response Time**: 4 hours
- **Escalation**: Notify Engineering Lead within 2 hours
- **Examples**:
  - High latency in ride matching
  - Some drivers not appearing on map
  - Occasional payment failures

#### P3 - Low (Minor Issues)
- **Definition**: Minor bugs or edge cases
- **Response Time**: Next business day
- **Escalation**: Standard bug tracking process
- **Examples**:
  - UI glitches
  - Non-critical metrics missing
  - Documentation updates needed

### Incident Response Checklist

#### Immediate Response (First 15 minutes)
- [ ] Acknowledge the alert in Slack (#incidents channel)
- [ ] Assess severity level using criteria above
- [ ] Create incident ticket in Jira with severity level
- [ ] If P0/P1: Start incident bridge call
- [ ] If P0: Notify CEO and Engineering Lead immediately
- [ ] Begin initial investigation using runbooks below

#### Investigation Phase
- [ ] Check primary dashboard for system health
- [ ] Review recent deployments in last 2 hours
- [ ] Check Cloud Console for any ongoing incidents
- [ ] Review error logs in Cloud Logging
- [ ] Identify root cause and document findings

#### Resolution Phase
- [ ] Implement fix or rollback
- [ ] Verify fix resolves the issue
- [ ] Monitor for 30 minutes to ensure stability
- [ ] Update incident ticket with resolution
- [ ] Send all-clear message to stakeholders

#### Post-Incident
- [ ] Schedule post-mortem meeting within 24 hours
- [ ] Document lessons learned
- [ ] Create action items to prevent recurrence
- [ ] Update runbooks and monitoring as needed

---

## 🧪 Load Testing Handbook

### Performance Testing Strategy

The platform uses JMeter for comprehensive performance testing with the following test scenarios:

#### Test Scenarios
- **Smoke Test**: 10 users, 60s ramp-up, 60s duration
- **Load Test**: 100 users, 2min ramp-up, 5min duration  
- **Stress Test**: 500 users, 5min ramp-up, 10min duration
- **Spike Test**: 1000 users, 1min ramp-up, 5min duration
- **Soak Test**: 200 users, 5min ramp-up, 30min duration

#### Running Performance Tests
```bash
# Navigate to performance test directory
cd backend/performance-tests

# Run load test on staging
./run-performance-tests.sh staging load

# Run stress test with custom parameters
./run-performance-tests.sh staging stress 500 600

# Run smoke test on production (use with caution)
./run-performance-tests.sh prod smoke
```

#### SLA Requirements
- **P95 Response Time**: < 2000ms for ride matching
- **Success Rate**: > 95% for all requests
- **Throughput**: > 10 req/sec sustained load
- **Error Rate**: < 5% under normal load

#### Interpreting Results
```bash
# Results are saved in multiple formats:
# - JTL file: Raw test data
# - HTML report: Detailed analysis with graphs
# - Summary report: Key metrics and SLA compliance
# - Alert file: Generated if SLA violations detected

# Example summary output:
Total Requests: 1500
Success Rate: 98.2%
Average Response Time: 1250ms
P95 Response Time: 1850ms
Throughput: 5.2 req/sec
SLA Status: PASS
```

#### Performance Troubleshooting
When performance issues are detected:

1. **Check Cloud Functions Metrics**
   - CPU utilization
   - Memory usage
   - Cold start frequency
   - Concurrency limits

2. **Analyze Database Performance**
   - Firestore read/write latency
   - Index usage efficiency
   - Query complexity

3. **Review Load Balancer Metrics**
   - Request distribution
   - Backend health
   - SSL termination latency

4. **Investigate External Dependencies**
   - Stripe API response times
   - Radar SDK performance
   - LiveKit connection latency

#### Automated Performance Monitoring
Performance tests run automatically:
- **Nightly**: Load test on staging environment
- **Pre-deployment**: Smoke test on target environment
- **Post-deployment**: Validation test with reduced load

Results are posted to `#engineering-alerts` Slack channel with SLA compliance status.

---

## 🔍 Common Issue Runbooks

### Ride Matching Failures

#### Symptoms
- Alert: "Unmatched Ride Requests > 10/min"
- Users reporting "No drivers available"
- High number of ride requests in "no-driver" state

#### Investigation Steps
1. **Check Planner Service Health**
   ```bash
   # Check Cloud Run service status
   gcloud run services describe ride-planner --region=us-central1
   
   # Check recent logs
   gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=ride-planner" --limit=50
   ```

2. **Check Driver Availability**
   ```bash
   # Query active drivers
   gcloud firestore query --collection-group=drivers --where="isAvailable==true" --limit=10
   ```

3. **Check Firestore Performance**
   - Navigate to Firestore console
   - Check for any ongoing operations or index builds
   - Review query performance metrics

#### Common Fixes
- **Planner Service Down**: Restart Cloud Run service
- **Database Issues**: Check Firestore quotas and indexes
- **Code Bug**: Rollback recent deployment if correlation found

### Payment Processing Issues

#### Symptoms
- Alert: "Stripe webhook failures"
- Users reporting payment declined
- Revenue dashboard showing drops

#### Investigation Steps
1. **Check Stripe Dashboard**
   - Login to Stripe dashboard
   - Review recent payment attempts
   - Check webhook delivery status

2. **Check Cloud Function Logs**
   ```bash
   gcloud logging read "resource.type=cloud_function AND resource.labels.function_name=stripeWebhook" --limit=50
   ```

3. **Verify Stripe Configuration**
   ```bash
   # Check if webhook secret is configured
   gcloud secrets versions access latest --secret="stripe-webhook-secret"
   ```

#### Common Fixes
- **Webhook Failures**: Redeploy webhook function
- **Secret Issues**: Update Stripe webhook secret
- **API Changes**: Check Stripe API version compatibility

### High Function Latency

#### Symptoms
- Alert: "Cloud Function P95 Latency > 2s"
- Users reporting slow app performance
- Timeout errors in logs

#### Investigation Steps
1. **Identify Slow Functions**
   ```bash
   # Check function execution times
   gcloud logging read "resource.type=cloud_function AND severity=ERROR" --limit=20
   ```

2. **Check Cold Starts**
   - Review function concurrency settings
   - Check if functions are scaling from zero

3. **Database Query Performance**
   - Check Firestore query performance
   - Look for missing indexes

#### Common Fixes
- **Cold Starts**: Increase minimum instances
- **Slow Queries**: Add database indexes
- **Memory Issues**: Increase function memory allocation

### LiveKit Connection Issues

#### Symptoms
- Users reporting "Can't hear other participants"
- High number of connection failures
- Audio/video quality complaints

#### Investigation Steps
1. **Check LiveKit Cloud Status**
   - Visit LiveKit Cloud status page
   - Review any ongoing incidents

2. **Check Token Generation**
   ```bash
   # Review LiveKit token function logs
   gcloud logging read "resource.type=cloud_function AND resource.labels.function_name=livekitToken" --limit=20
   ```

3. **Test Connection Manually**
   - Use LiveKit CLI to test room creation
   - Verify API keys are correct

#### Common Fixes
- **Token Issues**: Regenerate LiveKit API keys
- **Network Issues**: Check firewall rules
- **Capacity Issues**: Scale LiveKit resources

---

## 📈 Monitoring & Alerting

### Critical Alerts (Immediate Response Required)

#### Platform Health
- **Function Error Rate > 5/min**: Indicates system instability
- **Firestore Error Rate > 1%**: Database issues affecting all operations
- **Cloud Run 5xx Errors > 5%**: Planner service failing

#### Business Critical
- **Ride Completion Rate < 85%**: Major user experience impact
- **Unmatched Rides > 10/min**: Revenue loss and user frustration
- **Payment Failures > 5%**: Direct revenue impact

#### Security
- **Location Spoofing > 10/hour**: Potential fraud activity
- **Critical Inventory Mismatches > 0**: Safety concerns with child seats/capacity

### Warning Alerts (Monitor Closely)

#### Performance
- **Function P95 Latency > 2s**: Performance degradation
- **Driver Utilization < 60%**: Efficiency concerns
- **BigQuery Job Failures > 5/hour**: Analytics pipeline issues

### Alert Response Matrix

| Alert Type | Severity | Response Time | Escalation |
|------------|----------|---------------|------------|
| Platform Down | P0 | 15 min | CEO + Eng Lead |
| Payment Issues | P1 | 30 min | Eng Lead |
| High Latency | P2 | 1 hour | On-call engineer |
| Low Utilization | P3 | 4 hours | Product team |

---

## 🛠 Deployment Procedures

### Emergency Rollback

#### Cloud Functions
```bash
# List recent deployments
gcloud functions list --regions=us-central1

# Rollback specific function
gcloud functions deploy FUNCTION_NAME --source=./previous-version --trigger-http

# Or rollback all functions
firebase deploy --only functions --force
```

#### Cloud Run
```bash
# List revisions
gcloud run revisions list --service=ride-planner --region=us-central1

# Rollback to previous revision
gcloud run services update-traffic ride-planner --to-revisions=REVISION_NAME=100 --region=us-central1
```

#### Firestore Rules
```bash
# Deploy previous rules
firebase deploy --only firestore:rules --force
```

### Deployment Verification Checklist
- [ ] All functions responding to health checks
- [ ] No spike in error rates after deployment
- [ ] Key business metrics remain stable
- [ ] Sample ride flow works end-to-end
- [ ] Payment processing functional

---

## 🔧 Maintenance Procedures

### Weekly Tasks
- [ ] Review and triage P3 incidents
- [ ] Check quota usage and request increases if needed
- [ ] Review and update alert thresholds based on trends
- [ ] Clean up old logs and temporary resources
- [ ] Update this runbook with new learnings

### Monthly Tasks
- [ ] Review and rotate API keys/secrets
- [ ] Analyze cost trends and optimize resources
- [ ] Review and update disaster recovery procedures
- [ ] Conduct chaos engineering exercises
- [ ] Update capacity planning models

### Quarterly Tasks
- [ ] Full disaster recovery test
- [ ] Security audit and penetration testing
- [ ] Performance benchmarking and optimization
- [ ] Review and update SLAs
- [ ] Team training on new procedures

---

## 📋 Health Check Commands

### Quick System Status
```bash
#!/bin/bash
# Run this script for quick system health check

echo "=== Cloud Functions Status ==="
gcloud functions list --regions=us-central1 --format="table(name,status,updateTime)"

echo "=== Cloud Run Status ==="
gcloud run services list --regions=us-central1 --format="table(metadata.name,status.url,status.conditions[0].type)"

echo "=== Firestore Status ==="
gcloud firestore databases list --format="table(name,type,locationId)"

echo "=== Recent Errors ==="
gcloud logging read "severity=ERROR" --limit=5 --format="table(timestamp,resource.labels.function_name,textPayload)"

echo "=== Active Alerts ==="
gcloud alpha monitoring policies list --filter="enabled=true" --format="table(displayName,enabled,conditions[0].displayName)"
```

### Database Health Check
```bash
# Check Firestore performance
gcloud firestore operations list --filter="done=false"

# Check for failed operations
gcloud logging read "resource.type=firestore_database AND severity=ERROR" --limit=10
```

### Performance Baseline
```bash
# Get current function execution times
gcloud logging read "resource.type=cloud_function AND jsonPayload.executionTimeMs>1000" --limit=10
```

---

## 🚀 Scaling Procedures

### Traffic Surge Response
1. **Monitor Key Metrics**
   - Active ride requests
   - Function concurrency
   - Database read/write rates

2. **Scale Resources**
   ```bash
   # Increase Cloud Run instances
   gcloud run services update ride-planner --max-instances=50 --region=us-central1
   
   # Increase function memory if needed
   gcloud functions deploy singleHopMatcher --memory=1GB
   ```

3. **Database Scaling**
   - Monitor Firestore quotas
   - Request quota increases if approaching limits
   - Consider read replicas for read-heavy operations

### Capacity Planning
- **Normal Traffic**: 1000 concurrent rides
- **Peak Traffic**: 5000 concurrent rides  
- **Emergency Capacity**: 10000 concurrent rides

---

## 📞 Contact Information

### Internal Teams
- **Engineering**: #engineering-alerts
- **DevOps**: #devops-alerts  
- **Product**: #product-alerts
- **Customer Support**: #support-alerts

### External Vendors
- **LiveKit Support**: support@livekit.io
- **Stripe Support**: Via Stripe Dashboard
- **Google Cloud Support**: Via Cloud Console
- **Mapbox Support**: Via Mapbox Dashboard

---

*Last Updated: {{date}}*

*This runbook should be updated after each incident and reviewed monthly.* 