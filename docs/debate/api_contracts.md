# API Contracts (Callable Functions & Webhooks)

All requests authenticated via Firebase Auth unless stated. Idempotency keys recommended for write endpoints via `Idempotency-Key` header.

## Authentication
- Bearer: Firebase ID token
- Roles: user, debater, moderator, admin

## LiveKit
### getDebateToken
Request:
{
  "debateId": "string"
}
Response:
{
  "accessToken": "jwt",
  "url": "wss://<lk-cloud-domain>"
}
Errors: 403 if no entitlement.

## Media Sharing
### uploadSharedMedia (callable)
Request:
{
  "debateId": "string",
  "fileName": "string",
  "mimeType": "string"
}
Response:
{
  "mediaId": "string",
  "uploadUrl": "string",
  "publicUrl": "string"
}
Errors: 403 if not debater/moderator.

## Timeline
### addTimelineEvent (callable)
Request:
{
  "debateId": "string",
  "speakerUid": "string",
  "event": {
    "historicalDate": "ISO-8601",
    "title": "string",
    "description": "string",
    "sources": [{"title": "string", "url": "string"}]
  }
}
Response: { "eventId": "string" }
Errors: 400 if out of timeframe; 403 if not the speaker.

## Reactions
### setDebateReaction (callable)
Request:
{ "debateId": "string", "value": 1 | 0 | -1 }
Response: { "ok": true }

## Comments & Summaries
### submitComment (callable)
Request:
{ "debateId": "string", "text": "string", "clusterId": "string?" }
Response: { "commentId": "string" }

### summarizeComments (Pub/Sub/cron)
Input: none (internal)
Output: writes to debates.stats.commentSummary

## Watch Parties
### joinOrCreatePublicWatchParty (callable)
Request:
{
  "debateId": "string",
  "filters": { "gender": "string", "ageBracket?": "string", "locale?": "string", "language?": "string" }
}
Response:
{ "partyId": "string", "joinUrl": "string" }

## Payments
### buyTicket (callable)
Request:
{ "productId": "string", "debateId?": "string" }
Response:
{ "clientSecret": "string" }

### handleDebateTicketWebhook (HTTP)
Stripe webhook → grants entitlement doc

## Debates Scheduling
### createDebateRequest (callable)
Request:
{ "targetDebaterUids": ["uid"], "topic": "string", "proposedDatetime": "ISO-8601" }
Response: { "requestId": "string" }

### respondDebateRequest (callable)
Request:
{ "requestId": "string", "action": "accept" | "decline" }
Response: { "ok": true, "debateId?": "string" }

## Recommendations
### getRecommendations (callable)
Request: { "pageSize?": number, "pageToken?": "string" }
Response:
{
  "debates": [{ "debateId": "string", "score": number }],
  "nextPageToken?": "string"
}

## Entitlements
- Entitlement doc path: users/{uid}/entitlements/{debateId|SUB}
- Checked by getDebateToken and by CDN signed URL (see cdn_auth_spec.md)

## Error Model
- 400 INVALID_ARGUMENT
- 401 UNAUTHENTICATED
- 403 PERMISSION_DENIED
- 404 NOT_FOUND
- 409 ABORTED (duplicate request)
- 429 RESOURCE_EXHAUSTED (rate limit)
- 500 INTERNAL