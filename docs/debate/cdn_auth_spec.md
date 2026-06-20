# CDN Auth Spec (HLS Playback)

Goal: protect paywalled debates and replays. Spectators fetch HLS via CDN using short-lived signed URLs.

## Token
- JWT (HS256 or RS256)
- Issuer: liive-debate
- Claims:
  - sub: uid
  - debateId: string
  - entitlements: array<string> (e.g., ["MONTHLY_REPLAY_SUB", "DEBATE_EVENT_123"]) 
  - exp: unix epoch (<= 15 min)
  - nbf: not-before (<= 2 min back)
  - ver: token schema version

## Signing Keys
- RS256 recommended with rotating key IDs (kid). Store in Secret Manager; rotate quarterly.

## URL Structure
- master: https://cdn.example.com/hls/{debateId}/master.m3u8?token=JWT
- segments inherit the same query param (CDN rewrite)

## CDN (CloudFront or Cloudflare)
- Verify JWT at edge (Lambda@Edge/Cloudflare Worker) using public key
- Check exp/nbf and that user has required entitlement for path debateId
- Optionally bind to IP/Cookie to reduce token sharing

## Issuance
- App calls backend `getPlaybackToken(debateId)` (server verifies entitlement)
- Response returns signed URL(s)

## Clock Skew
- Allow ±60s

## Caching
- Segments: TTL 1 hour
- Manifests: TTL 3–10s
- Vary cache key by rendition path; not by token

## Revocation
- Keep tokens short-lived; support server-side denylist for known-abuse jtis

## Logging
- Log allow/deny with uid, debateId, reason; export to BigQuery for audits

## API
- getPlaybackToken (callable)
Request: { "debateId": "string" }
Response: { "playbackUrl": "string" }