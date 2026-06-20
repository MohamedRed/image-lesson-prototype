# Firestore Schema (Debate Platform)

Note: Field types use Firestore primitives. All timestamps are serverTimestamp.

## Collections & Documents

### users/{uid}
- displayName: string
- photoURL: string
- gender: string (required for matchmaking)
- ageBracket: string (e.g., "18-24", "25-34")
- interestVectors: array<number> (embedding, optional)
- roles: array<string> (e.g., ["debater", "moderator"]) 
- mutes: map { strikes: number, lastMutedAt: timestamp }

Indexes:
- Composite: roles array-contains + displayName asc (admin lists)

### debates/{debateId}
- title: string
- topicTags: array<string>
- startTime: timestamp
- endTime: timestamp
- timeframeStart: timestamp (historical lower bound)
- timeframeEnd: timestamp (historical upper bound)
- isLive: boolean
- paywalled: boolean
- replayURL: string (HLS manifest URL) [optional]
- createdBy: uid
- speakers: array<uid>
- stats: map { currentViewers: number, totalViews: number, likes: number, dislikes: number, commentSummary: array<ClusterSummary> }

Security: writable by moderator/creator; readable by all.

Indexes:
- isLive + startTime desc
- topicTags array-contains + startTime desc

### debates/{debateId}/timelines/{speakerUid}/events/{eventId}
- historicalDate: timestamp
- title: string
- description: string
- sources: array<{ title: string, url: string }>
- isWithinScope: boolean
- factCheckStatus: string ("verified" | "false" | "needsSource" | "unknown")
- createdAt: timestamp
- createdBy: uid (speakerUid)

Indexes:
- historicalDate asc
- factCheckStatus + historicalDate

### debates/{debateId}/comments/{commentId}
- authorUid: uid
- text: string
- sentiment: string [optional]
- createdAt: timestamp
- clusterId: string [optional] (AI-assigned)

Indexes:
- createdAt desc
- clusterId + createdAt desc

### debates/{debateId}/sharedMedia/{mediaId}
- ownerUid: uid (debater/moderator)
- type: string ("pdf" | "image" | "video")
- url: string (GCS signed URL)
- thumbURL: string [optional]
- createdAt: timestamp

Indexes:
- createdAt asc

### debates/{debateId}/debateReactions/{uid}
- value: number (+1 like, -1 dislike, 0 none)
- updatedAt: timestamp

Aggregation: Cloud Function updates debates.stats.likes/dislikes.

### debateRequests/{requestId}
- requesterUid: uid
- targetDebaterUids: array<uid>
- topic: string
- proposedDatetime: timestamp
- status: string ("pending" | "accepted" | "declined" | "expired")
- createdAt: timestamp

Indexes:
- targetDebaterUids array-contains + status
- requesterUid + createdAt desc

### watchParties/{partyId}
- hostUid: uid
- debateId: string
- isLive: boolean
- isPublic: boolean
- capacity: number
- startedAt: timestamp
- filters: map { gender: string, ageBracket?: string, locale?: string, language?: string }

Sub-collection: participants/{uid} { joinedAt: timestamp }

Indexes:
- debateId + isPublic + startedAt desc

### userRecommendations/{uid}
- debateIds: array<string> (top-N ordered)
- modelVersion: string
- generatedAt: timestamp

### archivedDebates/{debateId}
- title: string
- topicTags: array<string>
- replayURL: string
- speakers: array<uid>
- startTime: timestamp
- endTime: timestamp
- summary: string [optional]

### unclassifiedComments/{commentId}
- debateId: string
- authorUid: uid
- text: string
- createdAt: timestamp

### commentSummaryReactions/{clusterId}/users/{uid}
- value: number (+1/-1)
- updatedAt: timestamp


## Data Types
- ClusterSummary: { summary: string, likeCount: number, dislikeCount: number, commentCount: number }

## TTL / Retention
- Use TTL policies or cleanup jobs:
  - debates older than 30 days → move to archivedDebates and prune heavy fields
  - unclassifiedComments older than 7 days → must be classified or deleted

## Firestore Indexes (firestore.indexes.json hints)
- debates: [{ field: "isLive", order: "asc" }, { field: "startTime", order: "desc" }]
- debates: [{ field: "topicTags", arrayConfig: "CONTAINS" }, { field: "startTime", order: "desc" }]
- timelines.events: [{ field: "historicalDate", order: "asc" }]
- comments: [{ field: "clusterId", order: "asc" }, { field: "createdAt", order: "desc" }]
- debateRequests: [{ field: "targetDebaterUids", arrayConfig: "CONTAINS" }, { field: "status", order: "asc" }]

## Notes
- High-churn counters (likes, currentViewers) should be sharded or offloaded to Redis/Spanner with async backfill to Firestore.
- All client-writable fields must be covered by Security Rules (see security_rules.md).