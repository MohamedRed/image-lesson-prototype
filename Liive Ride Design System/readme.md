# Liive Ride — Design System

**Liive Ride** is the live, in-city ride-sharing product extracted from the **Liive Super App** (`liive-ios`) and treated here as a standalone app with its own design system. This system lets design and engineering produce on-brand Liive Ride screens, prototypes, and assets without re-deriving the visual language each time.

---

## What Liive Ride is

A native iOS-first ride-hailing experience with a distinctive feature set that the design must serve:

- **Live in-city rides** — request a curb-side pickup, watch the driver approach on a live map.
- **Single-gender safety pools** — riders can ride in driver/passenger pools matched on gender.
- **Multi-leg journeys (≤3 legs)** — when no single driver fits, the planner stitches 2–3 legs together with **transfer points** where the rider walks a short distance and switches cars.
- **Real-time constraints** — seats, luggage (backpack / suitcase / bulky), pets (small / large), and child seats (infant / forward / booster) are matched against live driver inventory.
- **Premium options** — vehicle brand, AC, Wi-Fi, exclusive ride.
- **Cost-share pricing** with a surge multiplier and an itemised fare breakdown.
- **In-ride voice** — a LiveKit audio channel between rider and driver (mute / unmute, connection state).
- **Safety** — a prominent **SOS** control, audio-recording opt-in, location sharing.
- **Smart pickup points** — Radar walk-isochrones pick the closest legal curb within the rider's walk radius.
- **Stripe payments** — card, Apple Pay, Link; tax & fees broken out.

The product is **Dark-Mode-first** (an explicit rule in the iOS styleguide) and lives mostly on a dark Mapbox map, so this design system anchors to dark with an opt-in light theme.

> **On the visual identity:** the ride feature's existing screens were an un-designed engineering prototype (stock-iOS defaults), *not* an intentional brand. So the **visual identity here was designed from scratch** — a premium, minimal direction codenamed **“TIDE”**: a cool ink canvas, a single luminous **aqua** accent, and the **Schibsted Grotesk** typeface. What we *kept* from the codebase is the **product** (features, flows) and the **content/tone** (real copy strings); what we **deliberately replaced** is the look.

---

## Sources (for anyone with access)

- **Codebase:** `liive-ios/` (mounted locally; SwiftUI + SPM monorepo "super app").
  - Ride feature: `liive-ios/Packages/RideSharingFeature/Sources/RideSharingFeature/`
    — `RideSharingView`, `RideHUD`, `VoiceHUD`, `MultiLegProgressView`, `TransferPointView`,
    `PaymentView`, `SOSButton`, `LocationPermissionView`, `RideSharingViewModel`, `BaseMapMarkers`.
  - Ride service: `liive-ios/Packages/RideSharingService/`
  - Super-app shell / home: `liive-ios/image-lesson-prototype/HomeDashboardView.swift`, `AppRootView.swift`
  - Styleguide: `liive-ios/ios_styleguide.md`
  - Product docs: `liive-ios/docs/ride-sharing/` (`api.md`, `ride_sharing_full_plan.md`, `architecture.mmd`, `run_book.md`, `security.md`)
  - Conventions: `liive-ios/docs/super_app_conventions.md`
- **Maps:** Mapbox (dark "streets" style). **Location:** Radar SDK. **Voice:** LiveKit. **Payments:** Stripe.

> There are **no brand logo or illustration assets** in the codebase (`Assets.xcassets` ships an empty AppIcon and default AccentColor). The Liive wordmark in `assets/` is a **typographic reconstruction**, not an official logo — see Caveats.

---

## CONTENT FUNDAMENTALS

How Liive Ride writes copy, drawn from real strings in the codebase.

- **Voice:** plain, reassuring, practical. It explains *why* before asking for something: *"We need your location to find nearby pickup points and calculate walk times to optimize your ride experience."*
- **Person:** addresses the rider as **"you"**; the app speaks as **"we"** ("We need…", "Your payment is secured by Stripe"). First-person plural for the product, second-person for the user.
- **Casing:**
  - **Titles / headings → Title Case:** "Location Access Required", "Smart Pickup Points", "Payment Summary", "Multi-Leg Journey".
  - **Body / descriptions → sentence case:** "Find the closest legal pickup zones within your walking distance."
  - **System badges / status → ALL CAPS, sparingly:** "COMING SOON", "SOS", "HELP".
- **Status language is short and literal:** "Searching for drivers…", "Planning multi-hop journey…", "Processing…", "Payment Complete", "Journey Complete". Connection states read as single words: *Connected, Reconnecting, Failed, Disconnected*.
- **Numbers & units:** compact and inline — `ETA: 4m`, `150m walk`, `~2 min`, `2 legs`, `Pay $12.50`. Money uses the locale currency formatter ($X.XX). Times collapse to `m` / `h Xm`.
- **Buttons are verb-first and specific:** "Request Ride", "Accept Ride", "Cancel Ride", "Enable Location Access", "Open Map", "Pay $12.50", "Call Emergency Services".
- **Emoji:** **not** used in production UI chrome. A couple of status strings use a single inline mark for emphasis (e.g. "Paid ✅"); treat this as the exception, not the rule. Everywhere else, meaning is carried by **SF Symbols**, not emoji.
- **Safety copy is explicit and calm**, never alarmist: *"This will immediately alert emergency services and your emergency contacts. Are you sure?"*
- **Tone vibe:** trustworthy utility. Confident, low-drama, a little protective. No marketing exclamation, no jokes, no slang.

---

## VISUAL FOUNDATIONS

The visual language is **“TIDE”** — a custom, premium-minimal identity built on familiar iOS *interaction* patterns (sheets, capsules, materials) but with its own deliberate color, type and mark. Calm, assured, map-centric.

- **Color:** a **cool ink** canvas with a single **luminous aqua** accent (`--accent` `#54E0C6`). The ink scale stacks by elevation (`#07121A` bg → `#0E1E2A` surface → `#15293A` raised). Status hues are premium and used strictly semantically: **mint** (`#2FD08A`) = connected / paid / driver / complete; **amber** (`#F5B83D`) = transfers, walking segments, surge; **coral** (`#FF5A5F`) = SOS, errors, the origin pin; **gold** (`#F5C24B`) = rating stars. Color is functional, never decorative — **no brand gradients**.
- **Type:** **Schibsted Grotesk** (bundled as a real webfont via `tokens/fonts.css`, so it ships identically on every platform). `--font-display` (Bold, tight negative tracking) drives titles, fares and the wordmark; `--font-sans` (Regular/Medium) is the UI default. The iOS-derived text-style scale is retained as tokens (Large Title 34 → Caption2 11). Fares/ETAs use **tabular numbers**. The **wordmark** is lowercase `liive` + an aqua “pulse” dot.
- **Spacing:** a **4 / 8-point** rhythm. Standard screen gutter is **16px**. Hit targets are **≥44px**.
- **Backgrounds:** predominantly the **live dark map** (Mapbox), with content floating above it in **frosted-glass HUD panels** and **bottom sheets**. No photographic hero imagery, no patterns/textures, no illustration. The map *is* the background.
- **Materials, transparency & blur:** heavy, intentional use of **`backdrop-filter: blur()` "materials"** (mirroring SwiftUI `.ultraThinMaterial` / `.thinMaterial`). HUD chips, the voice pill, and the multi-leg panel sit on translucent blurred surfaces so the map stays legible underneath. Blur is reserved for floating chrome *over the map*; solid surfaces are used inside opaque sheets.
- **Corner radii:** small chips **8px**, buttons/inputs **10px**, cards & HUD panels **12px**, feature cards **16px**, bottom sheets **20–28px**, pills/badges **fully rounded (capsule)**. Capsules are everywhere — status badges, mode pills, the voice HUD.
- **Cards:** filled surface (`--surface`), 12–16px radius, soft shadow `0 4px 8px rgba(0,0,0,.10)`; no borders in dark mode (elevation does the separating), optional 1px accent **stroke** only to mark an *active* element (e.g. the selected transfer point). No colored-left-border cards.
- **Shadows:** soft and downward. Cards `0 4px 8px /.10`; floating HUD `0 6px 20px /.28`; map pins `0 4px 10px /.35`; the SOS button carries a **coral glow** `0 6px 18px rgba(255,90,95,.45)`. Light, never harsh.
- **Borders / hairlines:** 1px cool separators at low opacity (`rgba(120,170,185,.18)` dark). Used between list rows and inside sheets.
- **Animation:** quick and **spring-like**. Camera eases (`ease(to:duration:0.5)`); entrances fade/slide with ease-out; the **SOS button pulses** continuously (1.5s ease-in-out, scale 1→1.2, fade out) as a living safety affordance. Motion is subtle and purposeful — no long, flashy transitions. Respects reduced-motion.
- **Hover/press states (touch):** controls **dim to ~60% opacity and shrink to ~0.96 scale** on press (the iOS button feel). Filled buttons darken to a pressed accent. No hover styling is assumed (touch-first), but web mockups may add a faint fill on hover.
- **Protection / legibility:** because content floats on a map, panels rely on **blur + translucency** rather than scrims; pins and markers carry their own drop shadows to read against any map tile.
- **Imagery vibe:** the only imagery is the **map** — cool, desaturated dark ink tiles with the **aqua** route line and **amber** walk segments. No warm photography, no grain.
- **Layout rules:** a fixed **status bar** top and **home indicator** bottom; primary CTA pinned to the bottom as a **full-width 50px capsule/rounded button**; transient info as **floating HUD** top or **bottom sheet**; the **SOS** control is fixed and always reachable during an active ride.

---

## ICONOGRAPHY

- **Primary system in the real app: SF Symbols.** Every icon in the ride feature is an Apple SF Symbol referenced by name — e.g. `car.fill`, `location.circle.fill`, `location.fill`, `figure.walk`, `figure.walk.circle`, `mappin.circle.fill`, `map.fill`, `arrow.triangle.swap`, `arrow.triangle.2.circlepath`, `mic.fill` / `mic.slash.fill`, `speaker.slash.fill`, `creditcard.fill`, `applelogo`, `link`, `clock.circle`, `gearshape.fill`, `exclamationmark.triangle.fill`, `antenna.radiowaves.left.and.right`, `hammer.circle`, `play.circle`. They inherit the label color and weight, and `.fill` variants are favoured.
- **SF Symbols cannot be redistributed or webfont-embedded**, and there are no exported icon assets in the codebase. **For web mockups, this system substitutes [Lucide](https://lucide.dev) via CDN** — a clean, consistent open-source set with rounded joins and a tunable stroke that approximates the SF Symbol feel. **This is a documented substitution; it is not pixel-identical to SF Symbols.** A name-mapping (SF Symbol → Lucide) is provided in `assets/icon-map.md`.
- Load Lucide from CDN in any mockup: `<script src="https://unpkg.com/lucide@latest"></script>` then `lucide.createIcons()`. Default stroke-width `2`, size `24`, `currentColor`.
- **Emoji are not used as icons.** **Unicode arrows** (→) appear occasionally as cheap connectors (e.g. driver-to-driver transition); prefer the `arrow.*` symbol equivalents where possible.
- Map markers (car, origin, destination, transfer) are **tinted glyphs on a pin** with a drop shadow — the car marker is the aqua accent, the origin mint, the destination coral, the transfer amber.

---

## Index / Manifest

Root files:
- `styles.css` — global entry point (imports only). Link this one file.
- `tokens/` — `fonts.css` (Schibsted Grotesk @font-face), `palette.css` (TIDE ink + aqua ramp), `semantic.css` (dark-first aliases), `typography.css`, `spacing.css`, `effects.css`, `base.css`.
- `assets/` — `wordmark.css` + brand specimen, `icon-map.md` (SF Symbol → Lucide).
- `components/` — reusable React primitives (see below).
- `ui_kits/liive-ride/` — full-screen click-through recreation of the rider app.
- `templates/ride-screen/` — a copy-ready "Live Ride Screen" starter (loads the system via `ds-base.js`).
- `handoff/` — **native build package** for iOS + Android: a paste-ready Codex command (`CODEX_PROMPT.md`), full build spec (`SPEC.md`), and TIDE tokens pre-translated to SwiftUI (`ios/`) and Jetpack Compose (`android/`).
- `guidelines/` — foundation specimen cards (Type, Colors, Spacing, Brand).
- `SKILL.md` — Agent-Skill manifest for downloading into Claude Code.

**Components:** Button, Badge, Pill, Card, ListRow, SegmentedControl, Switch, Stepper, Avatar, RatingStars, IconCircle, GlassPanel, BottomSheet, SOSButton, ProgressDots, MapMarker, DriverCard, FareRow.

**UI kit:** `ui_kits/liive-ride/` — Set Destination → Ride Options → Matching → Driver En-Route (live ride) → Payment & Rating.

> The Design System tab shows every specimen and component card. Open `ui_kits/liive-ride/index.html` for the interactive app recreation.

---

## Caveats

- **Fonts:** **Schibsted Grotesk** is bundled as a real webfont (`tokens/fonts.css`, served from the Fontsource CDN), so type ships consistently on every platform — no system-font dependency. Swap the `@font-face` `src` to self-host if you prefer.
- **Icons:** **Lucide is a substitution** for SF Symbols (see Iconography). Not identical to Apple's glyphs.
- **Logo:** there is **no official Liive logo** in the codebase; the wordmark is a typographic reconstruction. Replace `assets/` if you have the real brand mark.
- **Maps:** the map background in mockups is a static stylised stand-in, not live Mapbox tiles.
