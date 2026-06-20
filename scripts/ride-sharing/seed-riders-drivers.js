const admin = require('firebase-admin');

// Initialize admin SDK with emulator settings
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';

admin.initializeApp({
  projectId: 'liive-ios-local',
});

const db = admin.firestore();
const auth = admin.auth();

async function seedRideSharingData() {
  console.log('🚗 Seeding ride-sharing specific data...');

  try {
    // Clear existing ride-sharing data
    await clearCollection('drivers');
    await clearCollection('rideRequests');
    await clearCollection('pickupZones');

    // Create test drivers
    const drivers = [
      {
        id: 'driver1',
        name: 'John Driver',
        email: 'john@example.com',
        phone: '+1234567890',
        isAvailable: true,
        isOnline: true,
        currentLocation: new admin.firestore.GeoPoint(37.7749, -122.4194), // SF
        capacitySeats: 4,
        activePickups: 0,
        vehicle: {
          make: 'Toyota',
          model: 'Camry',
          year: 2021,
          color: 'Silver',
          licensePlate: 'ABC123'
        },
        rating: 4.8,
        completedRides: 150,
        gender: 'male',
        acceptsGenderPools: true,
        currentPassengerGenders: [],
        speedKmh: 0,
        walkRadiusM: 500
      },
      {
        id: 'driver2',
        name: 'Sarah Driver',
        email: 'sarah@example.com',
        phone: '+1234567891',
        isAvailable: true,
        isOnline: true,
        currentLocation: new admin.firestore.GeoPoint(37.7849, -122.4094), // Near SF
        capacitySeats: 4,
        activePickups: 0,
        vehicle: {
          make: 'Honda',
          model: 'Accord',
          year: 2022,
          color: 'Blue',
          licensePlate: 'XYZ789'
        },
        rating: 4.9,
        completedRides: 200,
        gender: 'female',
        acceptsGenderPools: true,
        currentPassengerGenders: [],
        speedKmh: 0,
        walkRadiusM: 500
      },
      {
        id: 'driver3',
        name: 'Mike Driver',
        email: 'mike@example.com',
        phone: '+1234567892',
        isAvailable: false,
        isOnline: true,
        currentLocation: new admin.firestore.GeoPoint(37.7649, -122.4294),
        capacitySeats: 6,
        activePickups: 2,
        vehicle: {
          make: 'Ford',
          model: 'Explorer',
          year: 2020,
          color: 'Black',
          licensePlate: 'SUV456'
        },
        rating: 4.7,
        completedRides: 100,
        gender: 'male',
        acceptsGenderPools: false,
        currentPassengerGenders: ['male', 'male'],
        speedKmh: 30,
        walkRadiusM: 500
      }
    ];

    // Create drivers
    for (const driver of drivers) {
      const driverId = driver.id;
      delete driver.id;
      await db.collection('drivers').doc(driverId).set({
        ...driver,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`✅ Created driver: ${driver.name}`);
    }

    // Create test pickup zones
    const pickupZones = [
      {
        id: 'zone1',
        name: 'Downtown SF',
        center: new admin.firestore.GeoPoint(37.7749, -122.4194),
        radiusMeters: 1000,
        capacityCars: 10,
        activePickups: 0,
        isLegal: true,
        restrictions: [],
        geohash: 's0000000'
      },
      {
        id: 'zone2',
        name: 'Mission District',
        center: new admin.firestore.GeoPoint(37.7599, -122.4148),
        radiusMeters: 800,
        capacityCars: 8,
        activePickups: 1,
        isLegal: true,
        restrictions: ['no_stopping_7am_9am'],
        geohash: 's0000001'
      },
      {
        id: 'zone3',
        name: 'Financial District',
        center: new admin.firestore.GeoPoint(37.7946, -122.3999),
        radiusMeters: 600,
        capacityCars: 15,
        activePickups: 3,
        isLegal: true,
        restrictions: [],
        geohash: 's0000002'
      }
    ];

    // Create pickup zones
    for (const zone of pickupZones) {
      const zoneId = zone.id;
      delete zone.id;
      await db.collection('pickupZones').doc(zoneId).set({
        ...zone,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`✅ Created pickup zone: ${zone.name}`);
    }

    // Create rider profiles in Firestore
    const riderProfiles = [
      {
        id: 'rider1',
        name: 'Alice Rider',
        email: 'rider1@example.com',
        phone: '+1234567893',
        gender: 'female',
        preferGenderPool: true,
        rating: 4.9,
        completedRides: 50,
        paymentMethods: ['card_ending_4242'],
        homeLocation: new admin.firestore.GeoPoint(37.7749, -122.4194),
        workLocation: new admin.firestore.GeoPoint(37.7946, -122.3999)
      },
      {
        id: 'rider2',
        name: 'Bob Rider',
        email: 'rider2@example.com',
        phone: '+1234567894',
        gender: 'male',
        preferGenderPool: false,
        rating: 4.7,
        completedRides: 30,
        paymentMethods: ['card_ending_1234'],
        homeLocation: new admin.firestore.GeoPoint(37.7599, -122.4148),
        workLocation: new admin.firestore.GeoPoint(37.7749, -122.4194)
      }
    ];

    for (const profile of riderProfiles) {
      const profileId = profile.id;
      delete profile.id;
      await db.collection('riders').doc(profileId).set({
        ...profile,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`✅ Created rider profile: ${profile.name}`);
    }

    console.log('\n✨ Ride-sharing data seeded successfully!');

  } catch (error) {
    console.error('❌ Error seeding ride-sharing data:', error);
    process.exit(1);
  }
}

async function clearCollection(collectionName) {
  const batch = db.batch();
  const snapshot = await db.collection(collectionName).get();
  snapshot.docs.forEach(doc => {
    batch.delete(doc.ref);
  });
  await batch.commit();
  console.log(`🗑️  Cleared collection: ${collectionName}`);
}

// Run if called directly
if (require.main === module) {
  seedRideSharingData().then(() => {
    console.log('\n👋 Ride-sharing seeding complete!');
    process.exit(0);
  }).catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { seedRideSharingData };