# Liive Ride — Native Build Spec (iOS + Android)

This is the source-of-truth brief for implementing **Liive Ride** as two **pure native** apps:
**iOS = SwiftUI**, **Android = Jetpack Compose**. The visual identity is the **"TIDE"**
design system in this repo. Match it exactly.

> **Design source of truth:** the web design system in this project — `readme.md` (full
> guide), `styles.css` + `tokens/*` (token values), `guidelines/*.html` (visual specimens),
> `components/**` (component specs + `.prompt.md` usage), `ui_kits/liive-ride/` (the full
> interactive rider flow). When a value is ambiguous, the token CSS wins.

---

## 1. Brand snapshot — "TIDE"
- **Mood:** premium, minimal, calm, assured. Map-centric, **dark-mode first**.
- **Accent:** luminous **aqua** `#54E0C6` (dark) / `#17A98F` (light). On-accent text is dark ink `#04161A`.
- **Canvas:** cool ink `#07121A` → surface `#0E1E2A` → raised `#15293A`.
- **Status (semantic, strict):** mint `#2FD08A` = connected/paid/complete · amber `#F5B83D` = transfers/walk/surge · coral `#FF5A5F` = SOS/error/origin · gold `#F5C24B` = stars.
- **Type:** **Schibsted Grotesk** (display weight + tight negative tracking for titles/fares/wordmark).
- **Wordmark:** lowercase `liive` + an aqua "pulse" dot.
- **No brand gradients. No emoji in chrome.** Color is functional only.

## 2. Drop-in tokens & reference components
Use the pre-translated files in this folder — do not re-derive hex/sizes by hand:
- **iOS:** `handoff/ios/` — tokens (`LiiveColors`, `LiiveTypography`, `LiiveLayout`) **plus ready components**: `LiiveButton`, `LiiveBadge`, `LiiveIconCircle`, `LiiveAvatar`, `LiiveRatingStars`, `LiiveGlassPanel`, `LiiveBottomSheet`, `LiiveSOSButton`, `LiiveDriverCard`.
- **Android:** `handoff/android/` — tokens (`Color.kt`, `Type.kt`, `Dimens.kt`, `Theme.kt`) **plus ready components**: `LiiveButton`, `LiiveBadge`, `LiiveIconCircle`, `LiiveAvatar`, `LiiveRatingStars`, `LiiveGlassPanel`, `LiiveBottomSheet`, `LiiveSosButton`, `LiiveDriverCard`.

These set the exact pattern (token usage, press states, composition). Build the remaining
components (§6) the same way. Wrap each app root in the theme provider (`LiiveTheme { … }`
on Android; inject `LiiveColor`/`LiiveFont` on iOS) and reference **semantic tokens only**.

## 3. Architecture
- **iOS:** follow `liive-ios/ios_styleguide.md` verbatim — modular SPM (`RideSharingFeature` + `RideSharingService`), **MVVM with Combine + async/await**, a `@Published` state enum per view, a single `handle(event:)`, DI via initializers, navigation via coordinator. Dark Mode must be correct.
- **Android:** single-module-per-feature, **MVVM/MVI** with a `StateFlow<UiState>` + `onEvent(Event)`, Hilt DI, Navigation-Compose. Mirror the iOS state machine 1:1.
- Keep the same `Service` protocol shape on both (mock + live implementations) so the UI is testable offline.

## 4. Fonts
- **iOS:** bundle Schibsted Grotesk TTFs (Regular/Medium/SemiBold/Bold), register in `Info.plist` `UIAppFonts`. Family name `"Schibsted Grotesk"`.
- **Android:** easiest is **Downloadable Fonts via the Google Fonts provider** (`Type.kt` is wired for it; Schibsted Grotesk is on Google Fonts). Or bundle TTFs in `res/font`.
- Get the files from Google Fonts ("Schibsted Grotesk") — the web DS uses the same family.

## 5. Iconography
The production apps use **native icon systems** (no Lucide — that was only for web mockups):
- **iOS → SF Symbols.** Use the SF Symbol names in `assets/icon-map.md` (the "SF Symbol" column): `car.fill`, `location.fill`, `mappin.circle.fill`, `figure.walk`, `arrow.triangle.swap`, `mic.fill`/`mic.slash.fill`, `creditcard.fill`, `shield.lefthalf.filled`, `person.2.fill`, `suitcase.fill`, `pawprint.fill`, `figure.child`, `star.fill`, `clock`, `phone.fill`, etc. Tint with the accent; favour `.fill` variants.
- **Android → Material Symbols** (Rounded). Equivalents: `directions_car`, `my_location`, `location_on`, `directions_walk`, `swap_horiz`, `mic`/`mic_off`, `credit_card`, `shield`, `group`, `luggage`, `pets`, `child_friendly`, `star`, `schedule`, `call`.

## 6. Component inventory → native
Build these primitives from the DS specs (`components/**/*.d.ts` + `.prompt.md`). The ones marked
**✓ provided** already have a native file in `handoff/{ios,android}/`; build the rest in the same style. Names → native:
| DS component | iOS (SwiftUI) | Android (Compose) | Notes |
|---|---|---|---|
| Button | `LiiveButton` ✓ | `LiiveButton` ✓ | primary/secondary/tinted/plain/destructive; press dims+shrinks |
| Badge | `LiiveBadge` ✓ | `LiiveBadge` ✓ | capsule; semantic color; optional status dot |
| IconCircle | `LiiveIconCircle` ✓ | `LiiveIconCircle` ✓ | tinted circular icon |
| Avatar | `LiiveAvatar` ✓ | `LiiveAvatar` ✓ | image/initials; accent ring = active speaker |
| RatingStars | `LiiveRatingStars` ✓ | `LiiveRatingStars` ✓ | gold `--star`; fractional fill |
| Card | `LiiveCard` | `LiiveCard` | surface, 12–16 radius, soft shadow; accent stroke when active |
| ListRow | `LiiveListRow` | `LiiveListRow` | leading icon · title/subtitle · trailing value/control/chevron |
| SegmentedControl | native `Picker(.segmented)` styled, or custom | custom segmented | sliding selected pill |
| Switch | `Toggle` tinted mint | `Switch` tinted mint | on = success/mint |
| Stepper | custom −/+ | custom −/+ | seats/bags/pets |
| GlassPanel | `LiiveGlassPanel` ✓ | `LiiveGlassPanel` ✓ | floats over the map only |
| BottomSheet | `LiiveBottomSheet` ✓ | `LiiveBottomSheet` ✓ | rounded top 28, opaque surface, safe-area bottom |
| SOSButton | `LiiveSOSButton` ✓ | `LiiveSosButton` ✓ | pulsing coral disc; coral glow; confirm dialog |
| ProgressDots | `LiiveProgressDots` | `LiiveProgressDots` | multi-leg journey |
| MapMarker | native map annotation | native map marker | car=accent, origin=mint, dest=coral, transfer=amber; white outline + shadow |
| DriverCard | `LiiveDriverCard` ✓ | `LiiveDriverCard` ✓ | avatar+name+rating+vehicle+plate+ETA |
| FareRow | `LiiveFareRow` | `LiiveFareRow` | label + tabular amount; emphasised total |

## 7. Screens & flow (rider app)
Mirror `ui_kits/liive-ride/` exactly. State machine: `destination → options → matching → enroute → complete`, persisted.
1. **Where to?** — live map (current location), search field, saved places (Home/Work/recents).
2. **Choose your ride** — tiers **Pool / Premium / Exclusive** (Pool = a 2-leg multi-hop journey with a transfer point); female-only safety-pool toggle; passenger + bag steppers; child-seat toggle; fare estimate; bottom-pinned capsule CTA.
3. **Finding your driver…** — curb-reservation + pool-matching state; cancel.
4. **Live ride** — animated driver marker on the aqua route; top glass HUD (voice-connected + mic mute); floating **SOS**; driver card + ETA; **multi-leg ProgressDots panel** when Pool transfers; message/cancel.
5. **Trip complete & pay** — Stripe fare breakdown, Apple Pay / Google Pay, star rating, pay → receipt.

## 8. Platform SDKs (from the codebase docs)
- **Maps/nav:** Mapbox (dark style) — iOS `MapboxMaps`, Android `mapbox-maps-android`. Custom-tint to the TIDE map tokens.
- **Voice:** LiveKit (audio + data) — rider/driver room per `ride_{id}`.
- **Location/isochrones:** Radar SDK (walk-radius pickup points).
- **Payments:** Stripe (PaymentSheet / Google Pay).
- **Backend:** Firebase Auth + Firestore + Cloud Functions; endpoints in `liive-ios/docs/ride-sharing/api.md`.

## 9. Acceptance criteria
- Side-by-side, iOS and Android are visually indistinguishable in layout, color, type and spacing — both matching `ui_kits/liive-ride/`.
- Dark mode is the default and is pixel-correct; light mode adapts via the provided light tokens.
- Zero raw hex / magic numbers in feature code — only semantic tokens.
- The full rider flow runs against a **mock service** with no backend.
- Schibsted Grotesk renders on both platforms; numbers (fares/ETAs) use tabular figures.
