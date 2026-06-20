const { seedRideSharingData } = require('../ride-sharing/seed-riders-drivers');
const { seedHomeServices } = require('../home-services/seed-home-services');

/**
 * Seeds data for all features in the super app
 * This is the main seeder that calls individual feature seeders
 */
async function seedAllFeatures() {
  console.log('🌱 Starting to seed data for all features...');
  
  try {
    // Seed ride-sharing data
    console.log('\n🚗 Seeding ride-sharing feature...');
    await seedRideSharingData();
    
    // Seed home services data
    console.log('\n🏠 Seeding home services feature...');
    await seedHomeServices();
    
    // Seed debate data (when available)
    console.log('\n🗣️ Debate data seeding - Not yet implemented');
    // await seedDebateData();
    
    // Seed image-lesson data (when available) 
    console.log('\n🎓 Image-lesson data seeding - Not yet implemented');
    // await seedImageLessonData();
    
    console.log('\n✨ All feature data seeded successfully!');
    console.log('📱 You can now test all features locally');
    console.log('🌐 Emulator UI: http://localhost:4000');

  } catch (error) {
    console.error('❌ Error seeding feature data:', error);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  seedAllFeatures().then(() => {
    console.log('\n👋 All features seeded! Press Ctrl+C to exit.');
  }).catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { seedAllFeatures };