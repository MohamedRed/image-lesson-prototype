# Environment & Secrets Matrix

Store secrets in GCP Secret Manager; reference via env vars in Cloud Run/Functions. For local dev, use `.env.local` files.

## Backend (Cloud Functions / Cloud Run)
- FIREBASE_PROJECT_ID
- GCP_LOCATION (e.g., us-central1)
- LIVEKIT_CLOUD_API_KEY
- LIVEKIT_CLOUD_API_SECRET
- LIVEKIT_CLOUD_URL (wss endpoint)
- LIVEKIT_EGRESS_WEBHOOK_SECRET (optional)
- STRIPE_SECRET_KEY
- STRIPE_WEBHOOK_SECRET
- STT_PROVIDER ("whisper" | "deepgram")
- STT_API_KEY
- GROK_API_KEY
- PERSPECTIVE_API_KEY (optional moderation)
- CDN_SIGNING_PRIVATE_KEY (PEM, RS256)
- CDN_SIGNING_KID
- CDN_BASE_URL (https://cdn.example.com)
- HLS_BUCKET (gs://debate-hls-output)
- FIRESTORE_SHARD_COUNT (e.g., 1000)
- REDIS_URL (if using Redis write-through)

## Web (Next.js)
- NEXT_PUBLIC_FIREBASE_API_KEY
- NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN
- NEXT_PUBLIC_FIREBASE_PROJECT_ID
- NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET
- NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID
- NEXT_PUBLIC_FIREBASE_APP_ID
- NEXT_PUBLIC_CDN_BASE_URL

## iOS
- Info.plist entries for Firebase, API base, CDN base
- LiveKit token retrieved via backend (no secret in app)

## Secret Rotation
- Keys rotated quarterly; use `kid` in JWT to support dual-publish during rotation.

## IAM & Permissions
- Cloud Functions SA: access Secret Manager read, Firestore, Pub/Sub, Storage, Billing export (read)
- Cloud Run SA (workers): Storage read/write (HLS), Pub/Sub consume, Secret Manager read
- Stripe webhook: invoker allowed only to Stripe IPs (or authenticated endpoint)