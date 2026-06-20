# Security Rules Specification

Pseudocode for Firestore and Storage rules.

## Firestore
Rules apply to authenticated users only unless stated.

### debates
allow read: if true;
allow create: if request.auth.uid != null && request.resource.data.createdBy == request.auth.uid;
allow update, delete: if isModeratorOrOwner();

### debates/{debateId}/timelines/{speakerUid}/events
allow create: if request.auth.uid == speakerUid && withinTimeframe();
allow read: if true;
allow update, delete: if isModeratorOrOwner();

### debates/{debateId}/sharedMedia
allow create: if isDebaterOrModerator();
allow read: if true;

### debates/{debateId}/debateReactions/{uid}
allow write: if request.auth.uid == uid && isValidReaction();
allow read: if request.auth.uid != null;

### debates/{debateId}/comments
allow create: if request.auth.uid != null && length(request.resource.data.text) <= 2000;
allow read: if true;

### debateRequests
allow create: if request.auth.uid == request.resource.data.requesterUid;
allow update: if isTargetDebater() || isAdmin();
allow read: if isTargetDebater() || request.auth.uid == resource.data.requesterUid;

### watchParties
allow create: if request.auth.uid != null;
allow read: if true;
allow update: if request.auth.uid == resource.data.hostUid || isAdmin();

### userRecommendations
allow read: if request.auth.uid == resource.id;

Helpers (to be implemented in rules):
- isModeratorOrOwner()
- isDebaterOrModerator()
- withinTimeframe()
- isTargetDebater()
- isValidReaction()

## Storage (debateMedia bucket)
match /debateMedia/{debateId}/{fileName} {
  allow write: if isDebaterOrModerator(debateId);
  allow read: if true; // public to viewers; URLs are signed at backend/CDN
}

## Rate Limiting (via backend)
- Enforce per-user quotas on callables (e.g., comments/minute) using Firestore counters or Redis; reject with 429.