### Meal Planning — Full Implementation Plan

---

### 1) Vision & Goals

- **Purpose**: Help users cook delicious meals at home with minimal friction, covering the full journey from idea → plan → shop → cook → share → track health.
- **Primary barriers solved**: knowledge, time, planning, shopping complexity, cleaning effort, nutrition tracking, cost optimization.
- **Experience**: AI-first, visual (short step videos), voice-guided, flexible plans, minimal utensils, ingredient reuse, low food waste.
- **Scope summary**:
  - Import recipes from social networks (user-provided links) and from in-app suggestions.
  - Generate weekly meal plans satisfying constraints (diet, cost, time, cuisine themes, allergies, utensils, training goals, medical support).
  - Produce consolidated grocery lists with price comparisons and pickup/delivery options.
  - Visual cooking mode with step videos, auto-timers, multi-cook coordination, voice assistant.
  - Health tracking and a 3D body interface to tailor nutrition to symptoms/organs.

---

### 2) Non-Goals (Phase 1)

- **No unauthorized scraping**: We will not store copyrighted video content; we store links/metadata and user notes. Extraction is user-initiated and compliant.
- **No medical diagnosis**: Nutrition suggestions are wellness-oriented, not medical advice.
- **No proprietary social data access** without agreements; prioritize public oEmbed/metadata and user-provided content.

---

### 3) Users & Key Use Cases

- **Busy professional**: Wants 20–30 min meals, minimal utensils, low cleaning; weekend can be complex.
- **Fitness-oriented**: Macros/targets, high protein, pre/post-workout meals, bulk cook for lunch.
- **Budget-conscious**: Ingredient reuse, price comparisons across stores, batch shopping.
- **Beginner cook**: Highly visual, voice guidance, minimal reading, error-proof steps/timers.
- **Family**: Multi-cook coordination, leftovers planned, flexible swapping per taste.

---

### 4) Requirements

- **Platform**: iOS 16+ (SwiftUI, Concurrency), modular architecture (Feature/Service), offline-friendly caches.
- **Security/Privacy**: Only store links/metadata for third-party content; respect user privacy; PII minimal.
- **Performance**: Meal plan generation < 5s typical (async job allowed with progress), smooth video playback, background tasks for downloads.
- **Reliability**: Graceful fallback to mock/local cache when backend unavailable.
- **Compliance**: Content rights respected; add share/attribution for creators; clear disclaimers for health advice.

---

### 5) Architecture Overview (Frontend vs Backend)

- **Frontend (iOS)**
  - Feature module `MealPlanningFeature`: UI, state, flows (onboarding, planner, grocery list, cooking mode, 3D body & chat, sharing).
  - Service module `MealPlanningService`: Swift protocols + concrete implementations to call backend; local caches; mocks for demo.
  - Share Extension: Add recipe URLs from Instagram/TikTok/YouTube to app.
  - Voice & media: On-device speech (ASR/TTS) via Apple APIs; optional backend NLP for complex prompts.

- **Backend**
  - Cloud Functions v2 (HTTP + scheduled) as orchestrator APIs. Auth remains v1 where applicable.
  - Firestore (data), Cloud Storage (assets like thumbnails and derived step-clips), Cloud Run or Workflows for long-running video/AI tasks.
  - Pub/Sub for async pipelines (ingestion → transcription → step extraction → nutrition mapping).
  - External data: optional nutrition DB (e.g., USDA FDC) and price data providers via connectors.

- **Key principle**: Heavy/AI/media processing runs in backend. iOS is a thin client for UX and local caching.

---

### 6) Data Model (high-level)

- **Recipe**
  - id, title, description, images, videoUrl, sourcePlatform (`instagram|tiktok|youtube|web`), sourceAuthor, sourceAttribution, tags, cuisines.
  - steps: [Step] (id, startTime, endTime, shortInstruction, utensilRefs, timerSec, videoClipUrl? optional),
  - ingredients: [Ingredient] (name, quantity, unit, notes, substitutions, allergens),
  - utensils: [Utensil] (name, category),
  - nutrition: NutrientProfile (macros, micronutrients, per serving), servings.

- **MealPlan**
  - id, userId, weekStartDate, preferences (dietary, allergies, macros, timeBudget, costBudget, cuisines, utensilsMinimize, weekendComplexityHigh: Bool, leftoversPolicy),
  - days: [DayPlan] with meals: [MealSlot] referencing Recipe ids (+ selected serving size, notes),
  - optimizationMetadata (score breakdown: cost, time, variety, constraints satisfied),
  - shoppingListId.

- **ShoppingList**
  - id, mealPlanId, normalizedItems: [GroceryItem] (ingredientKey, totalQuantity, unit, preferredBrands?, storeMappings, substitutions, priceEstimates: [StorePrice]).

- **UserPrefs**
  - cuisinesLiked, cuisinesAvoided, dislikedIngredients, allergies, macrosTargets, cookingSkill, utensilsAvailable, budgetTier, schedule (e.g., quick weekdays).

- **HealthProfile**
  - optional: tracked nutrients, goals, organ/symptom selections, flagged conditions (for guidance only).

---

### 7) API (Cloud Functions v2 HTTP — representative)

- **Recipes**
  - POST `recipes:import` { url } → { recipeId } (async pipeline kickoff)
  - GET `recipes/{id}` → Recipe
  - POST `recipes/{id}:segment` → derive steps/clips (idempotent)

- **Meal Plans**
  - POST `mealPlans:generate` { criteria, candidateRecipeIds? } → { mealPlanId } (async JOB)
  - GET `mealPlans/{id}` → MealPlan
  - POST `mealPlans/{id}:replaceMeal` { day, slot, recipeId } → MealPlan
  - POST `mealPlans:recommend` { gap/criteria } → [Recipe]

- **Shopping**
  - GET `mealPlans/{id}/shoppingList` → ShoppingList
  - POST `shopping:priceCompare` { listId, stores } → ShoppingList (with prices)
  - POST `shopping:order` { listId, store } → Order (handoff to MarketplaceService when applicable)

- **AI Assistant**
  - POST `ai:chat` { messages, context } → { reply, suggestedEdits, recipeSuggestions }
  - POST `ai:nutrition` { bodyRegions/symptoms, prefs } → tailored criteria + recipe suggestions

- **Integrations**
  - POST `rides:pickup` { orderId, pickupWindow } (delegates to RideSharingService)
  - POST `health:sync` { mealPlanId } → aggregates nutrients to Health feature

- **Auth**
  - Use Firebase Auth (v1 where required). All endpoints require auth; role checks if needed.

---

### 8) Backend Components & Pipelines

- **Ingestion Pipeline** (URL-based, user-initiated)
  - Fetch public metadata via oEmbed/yt-dlp-lite runner on Cloud Run (with strict robots, no storage of copyrighted video beyond ephemeral thumbnails).
  - If transcript available (YouTube), fetch; else ASR on Cloud Run (Whisper or Apple SDK server pairing) & store text only.
  - LLM step extractor: from transcript → steps with times, tools, temperatures; store as structured steps.
  - FFmpeg step clipper: generate optional short clips per step (if allowed under fair use/transformative; else skip and only show time-scrub to original).
  - Nutrition mapper: map ingredients → nutrition DB entries; compute macros per serving.

- **Meal Plan Engine**
  - Constraint builder from user prefs + available recipes + week template.
  - Optimizer: heuristic + optional CP-SAT (OR-Tools) for multi-objective (min cost/time, max variety, satisfy macros & allergies).
  - Post-processor: leftovers policy, utensil reuse clusters per day, weekend complexity bias.

- **Shopping & Pricing**
  - Ingredient normalization & unit conversion.
  - Store mappers (catalog connectors) to suggested SKUs; price cache; substitution recommendations.

- **AI Services**
  - Chat Orchestrator (Function v2) with RAG over user recipes/meal plans; tool-calls to recommendation/optimizer endpoints.
  - Safety filters (allergens, harmful instructions, policy checks).

- **Events & Schedules**
  - Cloud Scheduler: refresh price caches nightly; re-optimize weekly suggestions; purge temp assets.

---

### 9) iOS Modules & Contracts

- **Packages/MealPlanningService** (Swift)
  - `MealPlanningServicing` protocol; models (Recipe, Ingredient, Step, MealPlan, ShoppingList, etc.).
  - `FirestoreMealPlanningService`: real backend client.
  - `MockMealPlanningService`: no-network, demo content.
  - Factory (env-based) similar to existing `EventsServiceFactory`.

- **Packages/MealPlanningFeature** (SwiftUI)
  - Views: Onboarding, Discover/Import, Planner (week grid), Grocery List, Cooking Mode, 3D Body + AI, Sharing.
  - ViewModels (Main, PlannerVM, CookingVM, GroceryVM, BodyVM).
  - Share Extension target: receive URLs; save via `MealPlanningService.recipesImport(url:)`.

- **Design principles**:
  - Swift Concurrency + Combine for streams.
  - Strict separation: views call VMs; VMs call service protocol only.
  - Offline caches in service layer (per-entity caches, persistence via Core Data or SQLite if needed later).

---

### 10) UX Flow (high-level)

- **Onboarding**: dietary prefs, allergies, disliked items, utensils available, time/cost sliders, weekend complexity, leftovers policy.
- **Import Recipes**: paste link or Share Extension → ingestion pipeline kicks off → user gets preview within seconds; steps refine as async completes.
- **Plan Generation**: choose theme (e.g., Mexican week) + constraints → plan created → can replace any slot with search/suggestions.
- **Grocery List**: consolidated items; toggle substitutions; compare store prices; order pickup/delivery (handoff to Marketplace/RideSharing).
- **Cooking Mode**: step-by-step video segments; auto timers; voice assistant; parallel-task assignment for multiple people; utensil reuse guidance.
- **Memories**: photos after cooking; add notes; compile into a meal-plan memory; share to friends.
- **Health Sync**: push nutrients to Health feature; track trends.

---

### 11) 3D Body + Functional Nutrition Assistant

- **UI**: 3D human body (SceneKit/RealityKit); tap/select organs/symptoms.
  - On iOS 16: prefer SceneKit for broad compatibility.
- **Engine**: map selections → nutrient focuses (knowledge graph); generate constraints (e.g., anti-inflammatory, liver-support nutrients) → plan or suggestions.
- **Safety**: add disclaimers; “not medical advice”; never replace professional care.

---

### 12) AI Assistant (in-app)

- **Chat**: natural language replacements ("Swap Tuesday dinner with a Mexican burger under 25 min").
- **RAG**: over user’s saved recipes and verified recipe index.
- **Tools**: call `mealPlans:replaceMeal`, `mealPlans:recommend`, `shopping:priceCompare`.
- **Voice**: Apple on-device speech for commands; backend LLM for reasoning when needed.

---

### 13) Integrations (reuse existing services)

- **MarketplaceService**: pricing, SKU mapping, checkout handoff.
- **RideSharingService**: curbside pickup or delivery via driver network.
- **FriendsService**: sharing memories; group cooking sessions.
- **Health feature**: nutrient summary per day/week; calorie & macros totals.

---

### 14) Security, Privacy, Compliance

- **Content**: store links + derived metadata; no storing copyrighted videos wholesale; cache thumbnails minimally.
- **User Data**: secure Firestore rules; PII minimization; delete on request.
- **Allergy Safety**: hard constraints at all times; prominent warnings.
- **Legal**: attribute creators; prepare for partnerships/affiliate links.

---

### 15) Observability & Analytics

- **Metrics**: plan creation time, plan acceptance rate, swaps per week, grocery checkout rate, cooking completion, timers used, nutrition targets hit.
- **Tracing**: pipeline spans (ingestion → extraction → plan generation).
- **Errors**: ingestion failures, ASR/LLM errors, price service timeouts.

---

### 16) Performance Targets

- **Ingestion preview**: < 5s to show basic recipe (title, hero, basic steps placeholder), full extraction may continue async.
- **Plan generation**: < 5s typical (async allowed with spinner and progress updates).
- **Cooking mode**: video segments prefetch; timer latency < 100ms.

---

### 17) Rollout Plan (Phased)

- **Phase 0 (Spike)**: Define models, service protocol, mocks; import simple web recipes; hardcoded plan.
- **Phase 1 (MVP)**: Share Extension, manual link import, basic step extraction, weekly plan, grocery list, simple price estimate, cooking mode with timers, AI chat for swap.
- **Phase 2**: Ingredient normalization + proper price comparison; leftovers & utensil reuse optimization; health sync.
- **Phase 3**: 3D body assistant; multi-cook orchestration; partnerships; marketplace/ride handoff at scale.

- **Feature Flags**: gate each capability; safe rollback.
- **A/B Tests**: plan acceptance UX, AI suggestions tone, price compare sorting.

---

### 18) Testing Strategy

- **Unit**: service protocol mocks for plan generation, ingredient consolidation, time/cost scoring.
- **Integration**: end-to-end ingestion on test URLs; step extractor deterministic mode.
- **UI**: snapshot tests for planner grid, cooking mode, grocery list.
- **UAT**: real cooking sessions; measure step clarity and timing accuracy.

---

### 19) Risks & Mitigations

- **Content rights**: Only store links/metadata; transform using transcripts; fast path to remove upon request.
- **Price data volatility**: Cache + manual overrides; allow user to pick store quickly.
- **Nutrition accuracy**: Show source, allow user adjustments; align with Health feature processes.
- **Latency**: Use async jobs + progress; prefetch likely videos/steps.
- **Allergy safety**: Hard constraints at all times; prominent warnings.

---

### 20) Open Questions

- Preferred nutrition DB and license terms?
- Priority markets/stores for price integration?
- Partnership strategy with creators for step clips?

---

### 21) Firestore Collections (draft)

- `users/{userId}`
- `users/{userId}/recipes/{recipeId}`
- `users/{userId}/mealPlans/{mealPlanId}`
- `users/{userId}/shoppingLists/{listId}`
- `recipeIndex/{recipeId}` (curated/global)
- `priceCaches/{storeId}` (SKU mappings, prices)

Rules: users read/write own; recipeIndex read-only; priceCaches read by backend only.

---

### 22) iOS Package Structure (proposed)

- `Packages/MealPlanningService`
  - Sources/MealPlanningService/ (protocols, models, factory, clients, mocks)
- `Packages/MealPlanningFeature`
  - Sources/MealPlanningFeature/ (views, view models, routing)
- `MealPlanningShareExtension` target (URL intake)

---

### 23) API Surface (iOS Service Protocol — indicative)

- `importRecipe(from url: String) async throws -> String` (recipeId)
- `getRecipe(id: String) async throws -> Recipe`
- `generateMealPlan(criteria: PlanCriteria) async throws -> MealPlan`
- `getMealPlan(id: String) async throws -> MealPlan`
- `replaceMeal(planId: String, day: Int, slot: MealSlotType, recipeId: String) async throws -> MealPlan`
- `getShoppingList(planId: String) async throws -> ShoppingList`
- `priceCompare(listId: String, stores: [String]) async throws -> ShoppingList`
- `aiChat(messages: [AIMessage], context: [String: Any]) async throws -> AIReply`

All UI talks only to this protocol.

---

### 24) Implementation Milestones & Estimates (indicative)

- **Week 1–2**: Service/model scaffolding, mocks, MVP planner UI, import simple web recipes.
- **Week 3–4**: Ingestion pipeline (transcript + step extraction), basic cooking mode, Share Extension.
- **Week 5–6**: Grocery normalization, price compare v1, AI chat swap, offline caches.
- **Week 7–8**: Health sync, utensil/leftover optimization, polish & analytics.
- **Week 9+**: 3D body assistant, multi-cook orchestration, partnerships.

---

### 25) Dependencies & Reuse

- Reuse `MarketplaceService`, `RideSharingService`, `FriendsService`, `Health` feature for integrations.
- Backend: Firebase Functions v2, Firestore, Storage, Pub/Sub, optional Cloud Run for media/AI.
- iOS: SwiftUI, AVKit, Speech, BackgroundTasks; iOS 16 compatible APIs.

---

### 26) QA & Launch Checklist

- Feature flags configured; fallbacks to mock.
- Accessibility pass (VoiceOver, captions on steps, color contrast).
- Localization scaffolding.
- Legal copy for content attribution & health disclaimers.

---

### 27) Appendix — Optimization Notes

- **Objective**: minimize total cost/time; maximize variety; satisfy constraints.
- **Approach**: Weighted score + constraint checks; if needed CP-SAT for hard constraints (allergies/macros), else greedy with refinement.
