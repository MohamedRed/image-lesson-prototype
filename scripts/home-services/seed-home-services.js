#!/usr/bin/env node

/**
 * Home Services Seed Script
 * 
 * Seeds Firestore with test data for home services feature:
 * - Service categories
 * - Sample RFQs
 * - Professional profiles
 * - Bids and contracts
 * 
 * Usage: node scripts/home-services/seed-home-services.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../../local-dev/service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccountPath),
  databaseURL: 'https://your-project-id.firebaseio.com'
});

const db = admin.firestore();

// Service Categories
const serviceCategories = [
  {
    id: 'plumbing',
    name: 'Plumbing',
    nameAr: 'السباكة',
    nameFr: 'Plomberie',
    icon: 'wrench.fill',
    attributesSchema: {
      urgency: { type: 'select', options: ['urgent', 'same_day', 'flexible'], required: true },
      location: { type: 'select', options: ['bathroom', 'kitchen', 'outdoor', 'other'], required: true },
      issue_type: { type: 'multiselect', options: ['leak', 'blockage', 'installation', 'repair'] }
    },
    isActive: true,
    displayOrder: 1,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    id: 'electrical',
    name: 'Electrical',
    nameAr: 'الكهرباء',
    nameFr: 'Électricité',
    icon: 'bolt.fill',
    attributesSchema: {
      urgency: { type: 'select', options: ['urgent', 'same_day', 'flexible'], required: true },
      work_type: { type: 'multiselect', options: ['installation', 'repair', 'upgrade', 'inspection'] },
      voltage: { type: 'select', options: ['110V', '220V', 'other'] }
    },
    isActive: true,
    displayOrder: 2,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    id: 'painting',
    name: 'Painting',
    nameAr: 'الطلاء',
    nameFr: 'Peinture',
    icon: 'paintbrush.fill',
    attributesSchema: {
      surface_type: { type: 'multiselect', options: ['interior_walls', 'exterior_walls', 'ceiling', 'doors', 'windows'] },
      room_count: { type: 'number', min: 1, max: 10 },
      paint_type: { type: 'select', options: ['water_based', 'oil_based', 'specialty'] }
    },
    isActive: true,
    displayOrder: 3,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    id: 'cleaning',
    name: 'Cleaning',
    nameAr: 'التنظيف',
    nameFr: 'Nettoyage',
    icon: 'sparkles',
    attributesSchema: {
      service_type: { type: 'multiselect', options: ['deep_clean', 'regular_clean', 'move_out', 'post_construction'] },
      frequency: { type: 'select', options: ['one_time', 'weekly', 'biweekly', 'monthly'] },
      area_size: { type: 'select', options: ['small', 'medium', 'large', 'extra_large'] }
    },
    isActive: true,
    displayOrder: 4,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    id: 'carpentry',
    name: 'Carpentry',
    nameAr: 'النجارة',
    nameFr: 'Menuiserie',
    icon: 'hammer.fill',
    attributesSchema: {
      project_type: { type: 'multiselect', options: ['furniture_repair', 'custom_furniture', 'installation', 'renovation'] },
      material: { type: 'select', options: ['wood', 'mdf', 'plywood', 'other'] },
      complexity: { type: 'select', options: ['simple', 'moderate', 'complex'] }
    },
    isActive: true,
    displayOrder: 5,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    id: 'appliance_repair',
    name: 'Appliance Repair',
    nameAr: 'إصلاح الأجهزة',
    nameFr: 'Réparation d\'appareils',
    icon: 'wrench.and.screwdriver.fill',
    attributesSchema: {
      appliance_type: { type: 'multiselect', options: ['refrigerator', 'washing_machine', 'oven', 'ac', 'other'] },
      brand: { type: 'text', required: false },
      model: { type: 'text', required: false },
      issue_description: { type: 'textarea', required: true }
    },
    isActive: true,
    displayOrder: 6,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  }
];

// Test users
const testUsers = [
  {
    uid: 'customer1',
    email: 'customer1@test.com',
    name: 'Ahmed Hassan',
    role: 'customer'
  },
  {
    uid: 'customer2', 
    email: 'customer2@test.com',
    name: 'Fatima Al-Zahra',
    role: 'customer'
  },
  {
    uid: 'pro1',
    email: 'pro1@test.com',
    name: 'Youssef Benali',
    role: 'professional'
  },
  {
    uid: 'pro2',
    email: 'pro2@test.com', 
    name: 'Hafid Ouali',
    role: 'professional'
  },
  {
    uid: 'pro3',
    email: 'pro3@test.com',
    name: 'Khadija Mansouri',
    role: 'professional'
  }
];

// Professional profiles
const professionalProfiles = [
  {
    id: 'pro1',
    userId: 'pro1',
    businessName: 'Casablanca Plumbing Services',
    businessNameAr: 'خدمات السباكة الدار البيضاء',
    businessNameFr: 'Services de Plomberie Casablanca',
    serviceCategories: ['plumbing', 'appliance_repair'],
    serviceArea: {
      city: 'Casablanca',
      regions: ['Centre', 'Anfa', 'Maarif'],
      maxRadiusKm: 25
    },
    contact: {
      phone: '+212 6 12 34 56 78',
      whatsapp: '+212 6 12 34 56 78',
      email: 'pro1@test.com'
    },
    experience: {
      yearsInBusiness: 8,
      completedJobs: 150,
      specializations: ['Emergency repairs', 'Bathroom renovation', 'Water heater installation']
    },
    pricing: {
      hourlyRate: 120,
      minimumCharge: 200,
      currency: 'MAD'
    },
    availability: {
      workingHours: {
        monday: { start: '08:00', end: '18:00' },
        tuesday: { start: '08:00', end: '18:00' },
        wednesday: { start: '08:00', end: '18:00' },
        thursday: { start: '08:00', end: '18:00' },
        friday: { start: '08:00', end: '18:00' },
        saturday: { start: '09:00', end: '15:00' },
        sunday: null
      },
      emergencyAvailable: true
    },
    portfolio: [
      {
        title: 'Kitchen Renovation',
        description: 'Complete kitchen plumbing overhaul',
        imageUrl: 'https://example.com/portfolio1.jpg',
        completedAt: new Date('2024-01-15')
      }
    ],
    rating: {
      average: 4.8,
      count: 45,
      breakdown: { 5: 35, 4: 8, 3: 2, 2: 0, 1: 0 }
    },
    verification: {
      isVerified: true,
      verifiedAt: new Date('2024-01-01'),
      documents: ['business_license', 'insurance']
    },
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    id: 'pro2',
    userId: 'pro2',
    businessName: 'Elite Electrical Solutions',
    businessNameAr: 'حلول الكهرباء النخبة',
    businessNameFr: 'Solutions Électriques Elite',
    serviceCategories: ['electrical'],
    serviceArea: {
      city: 'Rabat',
      regions: ['Agdal', 'Hassan', 'Souissi'],
      maxRadiusKm: 20
    },
    contact: {
      phone: '+212 6 87 65 43 21',
      whatsapp: '+212 6 87 65 43 21',
      email: 'pro2@test.com'
    },
    experience: {
      yearsInBusiness: 12,
      completedJobs: 230,
      specializations: ['Smart home installation', 'Industrial wiring', 'Solar panels']
    },
    pricing: {
      hourlyRate: 150,
      minimumCharge: 250,
      currency: 'MAD'
    },
    availability: {
      workingHours: {
        monday: { start: '07:00', end: '19:00' },
        tuesday: { start: '07:00', end: '19:00' },
        wednesday: { start: '07:00', end: '19:00' },
        thursday: { start: '07:00', end: '19:00' },
        friday: { start: '07:00', end: '19:00' },
        saturday: { start: '08:00', end: '16:00' },
        sunday: null
      },
      emergencyAvailable: true
    },
    rating: {
      average: 4.9,
      count: 67,
      breakdown: { 5: 58, 4: 7, 3: 2, 2: 0, 1: 0 }
    },
    verification: {
      isVerified: true,
      verifiedAt: new Date('2024-01-01'),
      documents: ['electrical_license', 'insurance', 'certifications']
    },
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    id: 'pro3',
    userId: 'pro3',
    businessName: 'Perfect Paint Pro',
    businessNameAr: 'برو الطلاء المثالي',
    businessNameFr: 'Perfect Paint Pro',
    serviceCategories: ['painting', 'cleaning'],
    serviceArea: {
      city: 'Marrakech',
      regions: ['Gueliz', 'Hivernage', 'Medina'],
      maxRadiusKm: 30
    },
    contact: {
      phone: '+212 6 55 44 33 22',
      whatsapp: '+212 6 55 44 33 22',
      email: 'pro3@test.com'
    },
    experience: {
      yearsInBusiness: 6,
      completedJobs: 95,
      specializations: ['Interior painting', 'Decorative finishes', 'Color consultation']
    },
    pricing: {
      hourlyRate: 100,
      minimumCharge: 180,
      currency: 'MAD'
    },
    availability: {
      workingHours: {
        monday: { start: '08:00', end: '17:00' },
        tuesday: { start: '08:00', end: '17:00' },
        wednesday: { start: '08:00', end: '17:00' },
        thursday: { start: '08:00', end: '17:00' },
        friday: { start: '08:00', end: '17:00' },
        saturday: { start: '09:00', end: '14:00' },
        sunday: null
      },
      emergencyAvailable: false
    },
    rating: {
      average: 4.7,
      count: 28,
      breakdown: { 5: 22, 4: 4, 3: 2, 2: 0, 1: 0 }
    },
    verification: {
      isVerified: true,
      verifiedAt: new Date('2024-01-15'),
      documents: ['business_license', 'insurance']
    },
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  }
];

// Sample RFQs
const sampleRFQs = [
  {
    customerId: 'customer1',
    categoryId: 'plumbing',
    scope: {
      title: 'Kitchen sink leak repair',
      titleAr: 'إصلاح تسريب حوض المطبخ',
      titleFr: 'Réparation de fuite d\'évier de cuisine',
      description: 'The kitchen sink has been leaking under the cabinet for a few days. Need urgent repair.',
      descriptionAr: 'حوض المطبخ يتسرب تحت الخزانة منذ عدة أيام. أحتاج إصلاح عاجل.',
      descriptionFr: 'L\'évier de la cuisine fuit sous l\'armoire depuis quelques jours. Besoin d\'une réparation urgente.',
      urgency: 'urgent',
      serviceDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)),
      timeWindow: 'morning',
      requirements: ['Bring own tools', 'Clean up after work'],
      photos: []
    },
    location: {
      address: '123 Rue Mohammed V, Casablanca',
      coordinates: new admin.firestore.GeoPoint(33.5731, -7.5898),
      city: 'Casablanca',
      region: 'Centre'
    },
    budgetRange: {
      minMAD: 200,
      maxMAD: 500,
      currency: 'MAD'
    },
    status: 'open',
    bidCount: 0,
    viewCount: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000))
  },
  {
    customerId: 'customer2',
    categoryId: 'painting',
    scope: {
      title: 'Living room painting',
      titleAr: 'طلاء غرفة المعيشة',
      titleFr: 'Peinture du salon',
      description: 'Need to paint the living room walls. Room is approximately 20 square meters.',
      descriptionAr: 'أحتاج لطلاء جدران غرفة المعيشة. الغرفة حوالي 20 متر مربع.',
      descriptionFr: 'Besoin de peindre les murs du salon. La pièce fait environ 20 mètres carrés.',
      urgency: 'flexible',
      serviceDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 5 * 24 * 60 * 60 * 1000)),
      timeWindow: 'all_day',
      requirements: ['Use high-quality paint', 'Move furniture carefully'],
      photos: []
    },
    location: {
      address: '456 Avenue Hassan II, Rabat',
      coordinates: new admin.firestore.GeoPoint(34.0209, -6.8416),
      city: 'Rabat',
      region: 'Hassan'
    },
    budgetRange: {
      minMAD: 800,
      maxMAD: 1500,
      currency: 'MAD'
    },
    status: 'open',
    bidCount: 0,
    viewCount: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000))
  }
];

async function seedHomeServices() {
  console.log('🏠 Starting Home Services seed...');

  try {
    // Seed service categories
    console.log('📂 Seeding service categories...');
    for (const category of serviceCategories) {
      await db.collection('serviceCategories').doc(category.id).set(category);
      console.log(`  ✅ Created category: ${category.name}`);
    }

    // Seed professional profiles
    console.log('👷 Seeding professional profiles...');
    for (const profile of professionalProfiles) {
      await db.collection('proProfiles').doc(profile.id).set(profile);
      console.log(`  ✅ Created pro profile: ${profile.businessName}`);
    }

    // Seed sample RFQs
    console.log('📝 Seeding sample RFQs...');
    for (const rfq of sampleRFQs) {
      const docRef = await db.collection('rfqs').add(rfq);
      console.log(`  ✅ Created RFQ: ${rfq.scope.title} (ID: ${docRef.id})`);
    }

    console.log('✅ Home Services seed completed successfully!');
    console.log(`
📊 Summary:
  - ${serviceCategories.length} service categories
  - ${professionalProfiles.length} professional profiles  
  - ${sampleRFQs.length} sample RFQs

🚀 You can now:
  1. Browse service categories in the app
  2. Create new RFQs as a customer
  3. Submit bids as a professional
  4. Test the complete bidding workflow
    `);

  } catch (error) {
    console.error('❌ Error seeding home services data:', error);
    process.exit(1);
  }
}

async function clearHomeServices() {
  console.log('🧹 Clearing existing home services data...');

  const collections = ['serviceCategories', 'proProfiles', 'rfqs', 'bids', 'contracts', 'escrows', 'reviews', 'disputes'];
  
  for (const collection of collections) {
    const snapshot = await db.collection(collection).get();
    const batch = db.batch();
    
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    if (!snapshot.empty) {
      await batch.commit();
      console.log(`  🗑️  Cleared ${snapshot.size} documents from ${collection}`);
    }
  }
}

// Main execution
async function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--clear')) {
    await clearHomeServices();
  }
  
  await seedHomeServices();
  process.exit(0);
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { seedHomeServices, clearHomeServices };