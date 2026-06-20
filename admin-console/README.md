# Liive Super App Admin Console

A comprehensive web-based admin console for managing all features of the Liive super app platform.

## Features

### Home Services
- **Service Categories Management** - Create, edit, and manage service categories
- **RFQ Moderation** - Review and moderate service requests
- **Dispute Resolution** - Handle customer-professional disputes
- **Professional Verification** - Review and approve professional profiles
- **Real-time Dashboard** - Monitor platform statistics

### Future Feature Modules
- **Ride Sharing** - Driver management, trip monitoring, safety oversight
- **Debate Platform** - Content moderation, topic management, user verification
- **Image Lessons** - Educational content review, instructor management

## Setup

### Local Development

1. Start the Firebase emulators:
   ```bash
   cd backend/functions
   firebase emulators:start
   ```

2. Serve the admin console:
   ```bash
   cd admin-console
   python3 -m http.server 8000
   # Or use any local web server
   ```

3. Open http://localhost:8000 in your browser
4. Navigate to specific feature admin consoles:
   - Home Services: http://localhost:8000/home-services/
   - (Future features will be added here)

4. Sign in with an admin account (needs admin custom claim)

### Production Deployment

1. Update `firebase-config.js` with your production Firebase configuration

2. Deploy to Firebase Hosting or any web hosting service:
   ```bash
   firebase deploy --only hosting
   ```

## Admin User Setup

To create an admin user, use the Firebase Admin SDK:

```javascript
// Set admin custom claim
await admin.auth().setCustomUserClaims(uid, { admin: true });
```

Or use the Firebase CLI:

```bash
firebase auth:import users.json --hash-algo=scrypt
```

## Security

- Only users with the `admin` custom claim can access admin functions
- All admin actions are logged for audit purposes
- Sensitive operations require additional confirmation

## File Structure

```
admin-console/
├── index.html                    # Main admin console hub
├── shared/                       # Shared components and utilities
│   ├── firebase-config.js       # Firebase configuration
│   ├── auth.js                  # Shared authentication logic
│   └── components/              # Reusable UI components
├── home-services/               # Home services admin module
│   ├── index.html              # Home services admin interface
│   └── admin.js                # Home services admin logic
├── ride-sharing/                # Future: Ride sharing admin
├── debate/                      # Future: Debate platform admin
├── image-lessons/               # Future: Image lessons admin
└── README.md                   # This file
```

## Key Functions

### Categories Management
- List all service categories
- Create new categories with multi-language support
- Edit existing categories
- Activate/deactivate categories

### RFQ Moderation
- View all RFQs with filtering options
- Flag inappropriate content
- View detailed RFQ information

### Dispute Resolution
- View all disputes with status filtering
- Assign disputes to agents
- Resolve disputes with various resolution types
- Track dispute timeline and responses

### Professional Verification
- Review pending verification requests
- View submitted documents
- Approve or reject verification requests
- Manage verification tiers and badges

## Troubleshooting

### Common Issues

**Authentication Error**: Ensure the user has admin custom claim set
**Emulator Connection Issues**: Check that Firebase emulators are running on correct ports
**Function Timeout**: Some admin operations may take time due to data processing

### Debug Mode

Enable debug logging in browser console:
```javascript
localStorage.debug = 'admin:*';
```