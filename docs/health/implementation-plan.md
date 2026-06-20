## Health Feature — Implementation Plan (iOS 16+ and Backend)

### Vision
Provide an all-in-one health hub where users can aggregate their health data, set goals, receive AI-driven preventive and corrective guidance, and connect to relevant features (Food Delivery, Meal Planning, Activities, Trips, Friends) and professionals. Prioritize privacy, standards compliance, and safe, explainable recommendations.

### Objectives
- Centralize user health data and history (incidents, medications, allergies, conditions, vitals, activity).
- Integrate Apple Health (HealthKit) and popular wearables (via Apple Health or vendor SDKs where permitted).
- Provide preventive insights and multi-step improvement programs tailored to user goals.
- Enable competitions and leaderboards with strict anonymity and privacy.
- Offer curated and personalized health news and evidence-backed content; link to videos and research.
- Allow contacting and booking with health coaches and professionals (telehealth-ready).
- Enterprise-grade security, compliance, and observability.

### Non-Goals (initial)
- Diagnosing or replacing medical judgement. We provide wellness guidance; medical advice guards and disclaimers are required.
- Storing raw PHI beyond what is necessary; minimize and encrypt.

### Standards and Compliance
- Apple HealthKit for iOS data collection and permissions; read/write per user consent.
- FHIR (Fast Healthcare Interoperability Resources) for structured records where applicable (conditions, medications, observations). Use simplified internal models mapped to FHIR profiles.
- HIPAA-like safeguards (if operating in regulated contexts): encryption at rest, audit logs, access controls, BAA with vendors when necessary.
- GDPR/CCPA: consent, data export/delete, purpose limitation.

### High-Level Architecture
```mermaid
graph TD
    subgraph iOS[HealthFeature (iOS 16+)]
        UI[SwiftUI Views] --> VM[ViewModels]
        VM --> HS[Health Service (client)]
        HK[HealthKit Adapter]
        VA[Voice Assistant UI]
        UI --> VA
        UI --> HK
    end

    HS -->|HTTPS/JSON| API[Health API (Functions v2 / Cloud Run)]
    API --> AUTH[Firebase Auth]
    API --> SVC[Domain Services]
    SVC --> FS[Firestore]
    SVC --> STG[Cloud Storage]
    SVC --> TASKS[Cloud Tasks]
    SVC --> MQ[Pub/Sub]
    SVC --> BQ[BigQuery]
    SVC --> VTX[Vertex AI / LLM Orchestration]
    SVC --> NEWS[News Aggregator]
    SVC --> PRO[Professionals/Bookings]

    SVC --> FOOD[FoodDelivery/MealPlanning]
    SVC --> ACT[ActivitiesService]
    SVC --> TRIPS[TripsService]
    SVC --> FRIENDS[FriendsService]
```

### Clear Separation: Backend vs iOS
- Backend (must do):
  - Data normalization/mapping to internal schemas and FHIR where applicable.
  - Aggregation and analytics; risk scoring; preventive insight generation.
  - Program generation (multi-step plans) using LLMs with guardrails; evaluation loops.
  - Personalization and recommendations; experimentation and feedback learning.
  - Leaderboards with k-anonymity and geo-bucketing; anti-gaming checks.
  - News ingestion, classification, and personalization (entity/condition tagging).
  - Professional directory and booking orchestration (with verifications/compliance).
  - Security, consent tracking, audit logs, data retention policies.
- iOS (must not do):
  - No on-device medical diagnosis; avoid duplicating ranking/scoring algorithms.
  - No direct calls to news/professional sources without backend mediation.
- iOS (should do):
  - HealthKit reads/writes per consent; local summaries; background delivery where allowed.
  - Present programs, track adherence, collect explicit feedback and outcomes.

### Data Model (Internal, mapped to FHIR where relevant)
- Profile: demographics (minimal), consents, goals, measurement preferences, conditions.
- Incident: surgeries, injuries, hospitalizations with dates, notes, files.
- Medication: name, dosage, schedule, adherence logs.
- Observation: vitals (HR, BP, SpO2), labs (if user-provided), steps, workouts, sleep, weight, nutrition summary (from Meal Planning/Food logs).
- Program: id, goal, steps (tasks, workouts, nutrition actions, education), schedule, personalization factors, progress, outcomes.
- Insight: preventive tip with trigger (deficit/excess), evidence links, severity, recommended action.
- LeaderboardEntry: bucket (geo/age bracket), percentile, rank, anonymized id.
- NewsItem: id, tags (conditions, nutrients, workouts), source, credibility score, link previews.
- Professional: type (coach, dietician, physio, doctor), verification, ratings, availability, telehealth link.

### Firestore Schema (proposed)
- health_profiles/{userId}
- health_incidents/{userId}/items/{incidentId}
- health_medications/{userId}/items/{medId}
- health_observations/{userId}/daily/{date}
- health_programs/{userId}/items/{programId}
- health_insights/{userId}/items/{insightId}
- health_leaderboards/{bucket}/entries/{entryId}
- health_news/{region}/items/{newsId}
- health_professionals/{region}/items/{proId}
- health_consents/{userId}/items/{consentId}

Indexes for leaderboards by bucket/score, news by tag/recency, observations by date.

### Integrations and Reuse
- Meal Planning/Food Delivery: ingest nutrition logs; recommend meal plans aligned with programs; preventive tips about deficits/excess.
- Activities: workouts and steps; program tasks reference ActivitiesService; reward adherence.
- Trips: travel context modifies programs (jet lag, limited facilities) and preventive alerts.
- Friends: share opt-in summaries, competitions; private groups leaderboards.
- Payments/Marketplace: optional coach sessions, devices; Stripe for payments.
- AITutor/Voice pipeline: reuse existing capture/streaming and NLU orchestration.

### Voice Assistant
- Use on-device capture; backend NLU extracts goals, constraints, and state; produce next-step coaching.
- Guardrails: medical advice disclaimers; route medical concerns to professionals; escalate if red flags.
- Multi-turn plans with check-ins; adapt based on adherence and outcomes.

### Recommendations & Learning Loops
- Initial rules + heuristics (WHO/CDC/EFSA guidelines for activity and nutrients).
- Personalization features: baseline metrics, goals, constraints (injuries, conditions), schedule, preferences.
- Feedback: explicit (user ratings, completion) + implicit (observed improvements); update models in BQ/Vertex.
- A/B tests for program variations; measure outcome deltas.

### News & Evidence Content
- Sources: vetted health portals, PubMed/NIH, journals, reputable channels; store source credibility metadata.
- Personalization by conditions/goals and recency; safe summaries for lay users; links to papers/videos.
- Moderation pipeline to prevent misinformation; model citations retained.

### Leaderboards & Competitions
- Scoring: composite index of steps, active minutes, VO2 proxy, program adherence, resting HR trend, sleep quality (normalized for age/sex where possible).
- Privacy: k-anonymity buckets; no names; city/country/continent buckets; opt-in only.
- Anti-gaming: anomaly detection, device attestation signals, cross-check with HealthKit trends.

### Backend Implementation
- Functions v2 (TypeScript) + Cloud Run workers for heavy analytics.
- Scheduled ETL: aggregate daily observations; compute insights and scores.
- News fetchers (Cloud Run) with RSS/APIs; classify and tag via Vertex AI; store excerpts and links only.
- Professional directory: admin onboarding/verification workflow; calendar booking integration (Calendly/Google Calendar API) and video via existing meeting stack.
- Security: per-user Firestore rules; consent documents; encrypted blobs in Storage (e.g., PDFs for labs).
- Observability: structured logging, metrics for insight precision/recall, recommendation CTR, program completion.

### API Surface (HTTP JSON)
- GET /health/overview → profile, today summary, active program steps, insights
- GET /health/observations?range=… → paged observations
- POST /health/programs/create → goal + constraints → proposed program
- POST /health/programs/{id}/progress → log completion, feedback
- GET /health/insights → preventive tips + evidence links
- GET /health/leaderboard?bucket=city|country|continent → anonymized ranks
- GET /health/news → personalized feed
- POST /health/import/healthkit → signed upload manifest for batch summaries
- GET /health/professionals/search → directory + availability
- POST /health/appointments/book → booking payload → confirmation
- POST /health/voice/interpret → transcript → intent + next prompt

All endpoints authenticated; App Check; rate limiting; PII minimization in payloads.

### iOS App (SwiftUI, iOS 16+)
- HealthKit integration: steps, workouts, heart rate, sleep, weight, nutrition (where available); granular permissions UI; background delivery.
- Screens: Overview dashboard; Insights; Programs; Observations timeline; Leaderboards; News; Professionals & Appointments; Settings/Consents.
- MVVM with Combine/async; local caching; privacy-first UX; accessibility compliance.

### Privacy, Risk, and Safety
- Medical disclaimers; emergency escalation heuristics; “not for diagnosis” copy.
- Consent per data type; export/delete; data residency controls if needed.
- Model bias checks; locale-aware recommendations; avoid prescriptive language.

### Testing Strategy
- Unit: mappers (FHIR↔internal), score calculations, rules engine, consent flows.
- Contract: HealthKit ingestion stubs; calendar/telehealth connectors.
- Integration: end-to-end goal → program → adherence → outcomes.
- iOS UI: permissions UX, dashboard widgets, background delivery flows.
- Load: leaderboard aggregation, news ingestion; chaos on external APIs.

### Rollout Plan
- Phase 0: HealthKit-only read, insight MVP, private beta.
- Phase 1: Programs with coaching; news personalization; leaderboards opt-in.
- Phase 2: Professionals directory + bookings; telehealth pilot.
- Phase 3: Advanced learning loops, broader device support.

### Next Steps
- Define HealthKit data types and permissions set; implement ingestion and daily aggregation.
- Stand up insights rules engine and MVP programs.
- Wire integrations with Meal Planning and Activities; create leaderboard POC.



