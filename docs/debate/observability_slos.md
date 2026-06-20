# Observability & SLOs

## SLOs
- HLS Startup Time p95: ≤ 3.5s
- WebRTC Join Time p95 (debaters): ≤ 2.0s
- LiveKit Packet Loss p95: ≤ 2%
- Moderator Mute Reaction (speech-rule violation → mute): ≤ 1.5s p95
- STT Latency (speech end → transcript): ≤ 2.5s p95
- Fact-check Latency (claim queued → status): ≤ 10s p95 (near-real-time batch)
- API Error Rate: < 0.5% 5xx per 10 min

## Metrics (names)
- video_hls_start_ms, video_hls_rebuffer_ratio
- webrtc_join_ms, webrtc_rtt_ms, webrtc_packet_loss_pct
- sfu_cpu_pct, sfu_mem_pct, egress_drop_frames
- cdn_cache_hit_ratio, cdn_egress_gb
- stt_latency_ms, moderator_action_latency_ms, factcheck_latency_ms
- api_requests_total{status}, api_latency_ms

## Dashboards
- Live Video Health: HLS start, rebuffer, CDN hit, segment 404s
- LiveKit Health: SFU CPU/mem, packet loss, egress status
- App Health: API latency/errors, comment summarizer backlog
- Cost: egress GB, CDN GB, LLM minutes, STT minutes

## Alerts
- HLS startup p95 > 5s for 5 min → page
- Packet loss > 5% for 2 min in any region → page
- CDN hit ratio < 80% for 10 min → warn
- API 5xx > 1% over 10 min → page
- Summarizer backlog > 200 comments for 10 min → warn

## Tracing
- Propagate x-correlation-id across app → backend → LLM calls
- Instrument critical paths with OpenTelemetry

## Logging
- Structured logs (JSON) with userId hashed, debateId, requestId
- Export to BigQuery; 30-day retention in hot storage