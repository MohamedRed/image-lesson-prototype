import json
import random
import time
from datetime import datetime, timedelta
from typing import Dict, List, Any

from locust import HttpUser, task, between, events
from faker import Faker
import firebase_admin
from firebase_admin import credentials, firestore
from geopy.distance import geodesic
import numpy as np

# Initialize Faker for synthetic data
fake = Faker()

# San Francisco bounds for realistic coordinates
SF_BOUNDS = {
    'lat_min': 37.7049,
    'lat_max': 37.8199,
    'lng_min': -122.5161,
    'lng_max': -122.3574
}

class SyntheticDataGenerator:
    """Generates realistic synthetic data for load testing"""
    
    @staticmethod
    def random_sf_coordinate():
        """Generate random coordinate within San Francisco bounds"""
        lat = random.uniform(SF_BOUNDS['lat_min'], SF_BOUNDS['lat_max'])
        lng = random.uniform(SF_BOUNDS['lng_min'], SF_BOUNDS['lng_max'])
        return {'latitude': lat, 'longitude': lng}
    
    @staticmethod
    def generate_driver_data(driver_id: str) -> Dict[str, Any]:
        """Generate synthetic driver data"""
        location = SyntheticDataGenerator.random_sf_coordinate()
        
        return {
            'id': driver_id,
            'capacitySeats': random.choice([2, 4, 6, 8]),
            'currentLocation': location,
            'gender': random.choice(['female', 'male', 'nb']),
            'luggageCapacity': {
                'backpack': random.randint(0, 4),
                'suitcase': random.randint(0, 2),
                'bulky': random.randint(0, 1)
            },
            'childSeatInventory': {
                'infant': random.randint(0, 2),
                'forward': random.randint(0, 2),
                'booster': random.randint(0, 2)
            },
            'petLimits': {
                'small': random.randint(0, 2),
                'large': random.randint(0, 1)
            },
            'premiumCapabilities': {
                'vehicleBrand': random.choice(['Tesla', 'BMW', 'Mercedes', 'Audi', 'Toyota']),
                'hasAC': random.choice([True, False]),
                'hasWiFi': random.choice([True, False])
            },
            'routePolyline': f"encoded_polyline_{driver_id}",
            'activePickups': 0,
            'legs': [],
            'cargoLedger': [],
            'petLedger': [],
            'childSeatLedger': [],
            'currentPassengerGenders': [],
            'isOnline': True,
            'lastUpdated': datetime.utcnow().isoformat()
        }
    
    @staticmethod
    def generate_ride_request_data(request_id: str) -> Dict[str, Any]:
        """Generate synthetic ride request data"""
        origin = SyntheticDataGenerator.random_sf_coordinate()
        # Generate destination within 5-15 km of origin
        destination_distance = random.uniform(5, 15)  # km
        bearing = random.uniform(0, 360)  # degrees
        
        destination_point = geodesic(kilometers=destination_distance).destination(
            (origin['latitude'], origin['longitude']), bearing
        )
        
        destination = {
            'latitude': destination_point.latitude,
            'longitude': destination_point.longitude
        }
        
        return {
            'id': request_id,
            'origin': origin,
            'destination': destination,
            'geohash': f"geohash_{request_id[:8]}",
            'walkRadiusM': random.choice([200, 300, 400, 500]),
            'passengerCount': random.randint(1, 4),
            'luggageManifest': {
                'backpack': random.randint(0, 2),
                'suitcase': random.randint(0, 1),
                'bulky': random.randint(0, 1)
            },
            'pet': {
                'class': random.choice(['small', 'large']),
                'count': 1
            } if random.random() < 0.1 else None,
            'childPassengers': [
                {
                    'ageYears': random.randint(1, 12),
                    'weightKg': random.randint(10, 40)
                }
            ] if random.random() < 0.15 else [],
            'riderGender': random.choice(['female', 'male', 'nb']),
            'premiumRequested': random.choice([True, False]),
            'state': 'searching',
            'assignedDriverId': None,
            'fareBreakdown': {},
            'fareMultiplier': random.uniform(1.0, 2.5),
            'createdAt': datetime.utcnow().isoformat(),
            'maxWaitTimeMinutes': random.randint(5, 15)
        }

class DriverUser(HttpUser):
    """Simulates driver behavior in the ride-sharing platform"""
    wait_time = between(2, 8)
    weight = 1  # 5k drivers out of 25k total users
    
    def on_start(self):
        """Initialize driver with synthetic data"""
        self.driver_id = f"driver_{fake.uuid4()[:8]}"
        self.driver_data = SyntheticDataGenerator.generate_driver_data(self.driver_id)
        self.is_online = True
        self.current_ride = None
        
    @task(3)
    def publish_location(self):
        """Publish driver location update"""
        if not self.is_online:
            return
            
        # Update location slightly (simulate movement)
        current_loc = self.driver_data['currentLocation']
        new_lat = current_loc['latitude'] + random.uniform(-0.001, 0.001)
        new_lng = current_loc['longitude'] + random.uniform(-0.001, 0.001)
        
        # Keep within SF bounds
        new_lat = max(SF_BOUNDS['lat_min'], min(SF_BOUNDS['lat_max'], new_lat))
        new_lng = max(SF_BOUNDS['lng_min'], min(SF_BOUNDS['lng_max'], new_lng))
        
        location_update = {
            'driverId': self.driver_id,
            'location': {'latitude': new_lat, 'longitude': new_lng},
            'timestamp': datetime.utcnow().isoformat(),
            'heading': random.uniform(0, 360),
            'speed': random.uniform(0, 50)  # km/h
        }
        
        with self.client.post("/updateDriverLocation", 
                            json=location_update,
                            catch_response=True) as response:
            if response.status_code == 200:
                response.success()
                self.driver_data['currentLocation'] = {'latitude': new_lat, 'longitude': new_lng}
            else:
                response.failure(f"Location update failed: {response.status_code}")
    
    @task(2)
    def accept_ride_request(self):
        """Simulate accepting a ride request"""
        if not self.is_online or self.current_ride:
            return
            
        # Simulate receiving and accepting a ride request
        if random.random() < 0.3:  # 30% chance of getting a ride request
            ride_request = {
                'driverId': self.driver_id,
                'requestId': f"req_{fake.uuid4()[:8]}",
                'action': 'accept',
                'timestamp': datetime.utcnow().isoformat()
            }
            
            with self.client.post("/handleRideRequest",
                                json=ride_request,
                                catch_response=True) as response:
                if response.status_code == 200:
                    response.success()
                    self.current_ride = ride_request['requestId']
                else:
                    response.failure(f"Ride accept failed: {response.status_code}")
    
    @task(1)
    def complete_ride(self):
        """Simulate completing a ride"""
        if not self.current_ride:
            return
            
        completion_data = {
            'driverId': self.driver_id,
            'rideId': self.current_ride,
            'completedAt': datetime.utcnow().isoformat(),
            'finalLocation': self.driver_data['currentLocation']
        }
        
        with self.client.post("/completeRide",
                            json=completion_data,
                            catch_response=True) as response:
            if response.status_code == 200:
                response.success()
                self.current_ride = None
            else:
                response.failure(f"Ride completion failed: {response.status_code}")
    
    @task(1)
    def toggle_online_status(self):
        """Simulate going online/offline"""
        if random.random() < 0.05:  # 5% chance to toggle status
            self.is_online = not self.is_online
            
            status_update = {
                'driverId': self.driver_id,
                'isOnline': self.is_online,
                'timestamp': datetime.utcnow().isoformat()
            }
            
            with self.client.post("/updateDriverStatus",
                                json=status_update,
                                catch_response=True) as response:
                if response.status_code == 200:
                    response.success()
                else:
                    response.failure(f"Status update failed: {response.status_code}")

class RiderUser(HttpUser):
    """Simulates rider behavior in the ride-sharing platform"""
    wait_time = between(10, 30)
    weight = 4  # 20k riders out of 25k total users
    
    def on_start(self):
        """Initialize rider with synthetic data"""
        self.rider_id = f"rider_{fake.uuid4()[:8]}"
        self.current_request = None
        
    @task(5)
    def request_ride(self):
        """Request a new ride"""
        if self.current_request:
            return  # Already have an active request
            
        request_id = f"req_{fake.uuid4()[:8]}"
        ride_request = SyntheticDataGenerator.generate_ride_request_data(request_id)
        ride_request['riderId'] = self.rider_id
        
        start_time = time.time()
        
        with self.client.post("/requestRide",
                            json=ride_request,
                            catch_response=True) as response:
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                response.success()
                self.current_request = request_id
                
                # Record matching latency metric
                events.request.fire(
                    request_type="MATCH_LATENCY",
                    name="ride_matching",
                    response_time=response_time * 1000,  # Convert to ms
                    response_length=0,
                    exception=None,
                    context={}
                )
                
                # Check if match time meets SLA (<2s)
                if response_time > 2.0:
                    events.request.fire(
                        request_type="SLA_VIOLATION",
                        name="match_sla_violation",
                        response_time=response_time * 1000,
                        response_length=0,
                        exception=f"Match time {response_time:.2f}s exceeds 2s SLA",
                        context={}
                    )
            else:
                response.failure(f"Ride request failed: {response.status_code}")
    
    @task(2)
    def cancel_ride(self):
        """Cancel current ride request"""
        if not self.current_request:
            return
            
        if random.random() < 0.1:  # 10% chance to cancel
            cancellation = {
                'riderId': self.rider_id,
                'requestId': self.current_request,
                'reason': random.choice(['changed_mind', 'found_alternative', 'emergency']),
                'timestamp': datetime.utcnow().isoformat()
            }
            
            with self.client.post("/cancelRide",
                                json=cancellation,
                                catch_response=True) as response:
                if response.status_code == 200:
                    response.success()
                    self.current_request = None
                else:
                    response.failure(f"Ride cancellation failed: {response.status_code}")
    
    @task(1)
    def check_ride_status(self):
        """Check status of current ride request"""
        if not self.current_request:
            return
            
        with self.client.get(f"/rideStatus/{self.current_request}",
                           catch_response=True) as response:
            if response.status_code == 200:
                response.success()
                
                # Check if ride is completed
                try:
                    status_data = response.json()
                    if status_data.get('state') in ['completed', 'cancelled']:
                        self.current_request = None
                except:
                    pass
            else:
                response.failure(f"Status check failed: {response.status_code}")

# Custom event handlers for metrics collection
@events.init.add_listener
def on_locust_init(environment, **kwargs):
    """Initialize custom metrics tracking"""
    print("🚀 Starting Ride-Sharing Load Test")
    print(f"Target: {environment.host}")
    print("Metrics: Tracking match latency and SLA violations")

@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Log test start"""
    print(f"🎯 Load test started with {environment.runner.user_count} users")

@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Generate final report"""
    print("📊 Load Test Results Summary:")
    print(f"Total requests: {environment.stats.total.num_requests}")
    print(f"Total failures: {environment.stats.total.num_failures}")
    print(f"Average response time: {environment.stats.total.avg_response_time:.2f}ms")
    print(f"95th percentile: {environment.stats.total.get_response_time_percentile(0.95):.2f}ms")
    
    # Check SLA compliance
    match_stats = environment.stats.entries.get(("MATCH_LATENCY", "ride_matching"))
    if match_stats:
        avg_match_time = match_stats.avg_response_time
        p95_match_time = match_stats.get_response_time_percentile(0.95)
        
        print(f"\n🎯 Matching Performance:")
        print(f"Average match time: {avg_match_time:.2f}ms")
        print(f"P95 match time: {p95_match_time:.2f}ms")
        print(f"SLA Compliance (<2s): {'✅ PASS' if p95_match_time < 2000 else '❌ FAIL'}")

if __name__ == "__main__":
    # This allows running the script directly for testing
    print("Run with: locust -f locustfile.py --users 25000 --spawn-rate 100")
    print("Driver:Rider ratio will be 1:4 (5k drivers, 20k riders)") 