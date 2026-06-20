# PubSub Emulator Local Development

## 🚀 **Official Google Cloud PubSub Emulator**

We use the **official Google Cloud PubSub emulator** for 100% API compatibility with production.

### **Service Configuration**

```yaml
# Docker Compose Service
pubsub-emulator:
  ports: "8085:8085"
  project: "liive-ios-local" 
```

### **Environment Variables**

```bash
# Automatic detection in client libraries
export PUBSUB_EMULATOR_HOST=localhost:8085
export PUBSUB_PROJECT_ID=liive-ios-local
```

## 📋 **Topic/Subscription Setup**

### **Create Topics and Subscriptions**

```bash
# Using gcloud CLI locally
export PUBSUB_EMULATOR_HOST=localhost:8085

# Create topics
gcloud pubsub topics create ride-events --project=liive-ios-local
gcloud pubsub topics create driver-location-updates --project=liive-ios-local
gcloud pubsub topics create payment-events --project=liive-ios-local

# Create subscriptions
gcloud pubsub subscriptions create notification-service \
  --topic=ride-events --project=liive-ios-local

gcloud pubsub subscriptions create analytics-service \
  --topic=ride-events --project=liive-ios-local

gcloud pubsub subscriptions create billing-service \
  --topic=payment-events --project=liive-ios-local
```

### **Or via Docker**

```bash
# Execute commands in the emulator container
docker-compose exec pubsub-emulator gcloud pubsub topics create ride-events --project=liive-ios-local
```

## 💻 **Client Library Usage**

### **Node.js (Cloud Functions)**

```javascript
const { PubSub } = require('@google-cloud/pubsub');

// Client automatically detects emulator via PUBSUB_EMULATOR_HOST
const pubsub = new PubSub({ projectId: 'liive-ios-local' });

// Publisher
async function publishRideEvent(rideId, event) {
  const topic = pubsub.topic('ride-events');
  const message = {
    rideId,
    event,
    timestamp: new Date().toISOString()
  };
  
  await topic.publishMessage({
    data: Buffer.from(JSON.stringify(message))
  });
}

// Subscriber
function startEventListener() {
  const subscription = pubsub.subscription('notification-service');
  
  subscription.on('message', (message) => {
    const data = JSON.parse(message.data.toString());
    console.log('Received event:', data);
    
    // Process the event
    handleRideEvent(data);
    
    // Acknowledge the message
    message.ack();
  });
}
```

### **Go (Planner Service)**

```go
package main

import (
    "context"
    "cloud.google.com/go/pubsub"
)

func publishDriverMatch(ctx context.Context, rideID, driverID string) error {
    // Client automatically detects emulator
    client, err := pubsub.NewClient(ctx, "liive-ios-local")
    if err != nil {
        return err
    }
    defer client.Close()
    
    topic := client.Topic("ride-events")
    result := topic.Publish(ctx, &pubsub.Message{
        Data: []byte(fmt.Sprintf(`{
            "event": "driver-matched",
            "rideId": "%s",
            "driverId": "%s"
        }`, rideID, driverID)),
    })
    
    _, err = result.Get(ctx)
    return err
}
```

## 🔧 **Development Commands**

### **List Topics and Subscriptions**

```bash
# List topics
docker-compose exec pubsub-emulator gcloud pubsub topics list --project=liive-ios-local

# List subscriptions  
docker-compose exec pubsub-emulator gcloud pubsub subscriptions list --project=liive-ios-local
```

### **Publish Test Messages**

```bash
# Publish test message
docker-compose exec pubsub-emulator gcloud pubsub topics publish ride-events \
  --message='{"event":"test","rideId":"test_123"}' \
  --project=liive-ios-local
```

### **Pull Messages**

```bash
# Pull messages from subscription
docker-compose exec pubsub-emulator gcloud pubsub subscriptions pull notification-service \
  --auto-ack --project=liive-ios-local
```

## 📊 **Event Schema**

### **Ride Events**

```json
{
  "topic": "ride-events",
  "schema": {
    "event": "ride-requested|driver-matched|ride-started|ride-completed",
    "rideId": "string",
    "driverId": "string?",
    "timestamp": "ISO8601",
    "data": "object"
  }
}
```

### **Driver Location Updates**

```json
{
  "topic": "driver-location-updates", 
  "schema": {
    "driverId": "string",
    "location": {"lat": "number", "lng": "number"},
    "speed": "number",
    "heading": "number",
    "timestamp": "ISO8601"
  }
}
```

### **Payment Events**

```json
{
  "topic": "payment-events",
  "schema": {
    "event": "payment-started|payment-completed|payment-failed",
    "rideId": "string", 
    "amount": "number",
    "currency": "string",
    "stripePaymentId": "string",
    "timestamp": "ISO8601"
  }
}
```

## 🎯 **Benefits vs Redis**

### **Production Parity** ✅
- **Same API**: Exact same client library calls
- **Same behavior**: Topics, subscriptions, acks, retries
- **Same monitoring**: Same metrics and debugging

### **Feature Completeness** ✅
- **Message ordering**: Guaranteed order when needed
- **Dead letter queues**: Failed message handling
- **Retry policies**: Configurable retry behavior
- **Filter expressions**: Subscribe to message subsets

### **Easy Migration** ✅
```javascript
// Same code works in local and production
const pubsub = new PubSub({ 
  projectId: process.env.NODE_ENV === 'production' ? 
    'liive-production' : 'liive-ios-local' 
});
```

## 🚨 **Troubleshooting**

### **Connection Issues**

```bash
# Check if emulator is running
curl http://localhost:8085

# Check emulator logs
docker-compose logs pubsub-emulator

# Test with gcloud
export PUBSUB_EMULATOR_HOST=localhost:8085
gcloud pubsub topics list --project=liive-ios-local
```

### **Message Not Received**

```bash
# Check subscription exists
gcloud pubsub subscriptions describe notification-service --project=liive-ios-local

# Check for unacknowledged messages
gcloud pubsub subscriptions pull notification-service --limit=10 --project=liive-ios-local
```