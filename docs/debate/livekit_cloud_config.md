# LiveKit Cloud Configuration

## Rooms
- Name: debate_{debateId}
- MaxParticipants: 64 (interactive on-stage)
- Egress: enabled (HLS template)
- DisconnectOnStop: true
- Audio: opus 48k, bitrate 32–64 kbps
- Video publish: simulcast on (low/medium/high)

Permissions
- Debater: canPublish = true, canSubscribe = true, canPublishData = true
- Spectator (web HLS): no WebRTC join; watches via HLS only
- Moderator bot: canMute, canRemove, canPublishData

## Regions
- Enable LiveKit Cloud auto region selection; allowlist: us-east, us-west, eu-west, ap-southeast

## Data Tracks (events)
- timeline_event_added { debateId, speakerUid, eventId }
- moderation_action { type: "mute" | "warning", targetUid }
- media_shared { mediaId, type }
- factcheck_update { eventPath, status }

## HLS Egress Template
- Renditions:
  - 1080p30 @ 4.0 Mb/s
  - 720p30 @ 2.2 Mb/s
  - 480p30 @ 1.2 Mb/s
- Audio: AAC LC 128 kbps
- Segment: 6s; Playlist: 5 segments
- LL-HLS: optional (enable for premium events)
- Destination: gs://debate-hls-output/{debateId}/master.m3u8

## Recording (optional VOD backup)
- Composite layout: grid of active speakers
- Mix minus audience tiles

## Webhooks (LiveKit → Backend)
- participant_joined/left → update currentViewers counter (spectators via CDN not included)
- egress_started/stopped → update debate status
- room_finished → finalize debate doc

## Monitoring
- Use LiveKit Cloud dashboard; export metrics via Cloud API to BigQuery hourly
- Key KPIs: packet loss %, SFU CPU, egress drop frames, bitrate per layer