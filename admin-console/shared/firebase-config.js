// Firebase configuration for admin console
// Update this with your actual Firebase project configuration

const firebaseConfig = {
  // For local development with emulators
  development: {
    apiKey: "demo-key",
    authDomain: "demo-project.firebaseapp.com",
    projectId: "demo-project",
    storageBucket: "demo-project.appspot.com",
    messagingSenderId: "123456789",
    appId: "demo-app-id"
  },
  
  // Production configuration (replace with your actual values)
  production: {
    apiKey: "your-api-key",
    authDomain: "your-project.firebaseapp.com",
    projectId: "your-project-id",
    storageBucket: "your-project.appspot.com",
    messagingSenderId: "your-sender-id",
    appId: "your-app-id"
  }
};

// Auto-detect environment
const isLocalhost = location.hostname === 'localhost' || location.hostname === '127.0.0.1';
const config = isLocalhost ? firebaseConfig.development : firebaseConfig.production;

// Initialize Firebase with the appropriate config
firebase.initializeApp(config);

// Use emulators for local development
if (isLocalhost) {
  firebase.auth().useEmulator('http://localhost:9099');
  firebase.firestore().useEmulator('localhost', 8080);
  firebase.functions().useEmulator('localhost', 5001);
  
  console.log('🔧 Using Firebase emulators for local development');
  console.log('📊 Emulator UI: http://localhost:4000');
}