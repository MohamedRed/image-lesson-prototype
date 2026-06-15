# Codex Command — Build Liive Ride (native iOS + Android)

Paste the block below to Codex (adjust the repo paths if you place the design system
somewhere other than the repo root). It points Codex at the spec + drop-in tokens and
constrains it to match the **TIDE** design system exactly.

---

```
You are building "Liive Ride", a live in-city ride-sharing app, as TWO pure-native apps:
iOS in SwiftUI and Android in Jetpack Compose. Do NOT use cross-platform frameworks.

SOURCE OF TRUTH — read these first, in order:
1. handoff/SPEC.md                     ← the build spec (read fully, follow exactly)
2. readme.md                           ← the "TIDE" design system guide (brand, content, visuals)
3. tokens/*.css + styles.css           ← exact token values (colors, type, spacing, radii)
4. components/**/*.d.ts + *.prompt.md  ← component contracts + usage
5. ui_kits/liive-ride/                 ← the full interactive rider flow to replicate
6. liive-ios/ios_styleguide.md         ← iOS architecture rules (MVVM/Combine/SPM) — follow verbatim
7. liive-ios/docs/ride-sharing/api.md  ← backend endpoints & data models

USE THE PRE-TRANSLATED TOKENS + COMPONENTS (do not re-derive hex/sizes by hand):
- iOS:     handoff/ios/  — tokens {LiiveColors,LiiveTypography,LiiveLayout}.swift +
           ready components {LiiveButton,LiiveBadge,LiiveIconCircle,LiiveAvatar,
           LiiveRatingStars,LiiveGlassPanel,LiiveBottomSheet,LiiveSOSButton,LiiveDriverCard}.swift
- Android: handoff/android/ — tokens {Color,Type,Dimens,Theme}.kt +
           ready components {LiiveButton,LiiveBadge,LiiveIconCircle,LiiveAvatar,
           LiiveRatingStars,LiiveGlassPanel,LiiveBottomSheet,LiiveSosButton,LiiveDriverCard}.kt
  These set the exact pattern. Build the remaining components (ProgressDots, MapMarker,
  ListRow, SegmentedControl, Switch, Stepper, Card, FareRow) the same way.

BRAND (TIDE) — non-negotiable:
- Dark-mode FIRST. Accent = aqua #54E0C6 (dark) / #17A98F (light), on-accent ink #04161A.
- Canvas ink #07121A → surface #0E1E2A → raised #15293A.
- Status: mint #2FD08A (connected/paid), amber #F5B83D (transfers/walk/surge),
  coral #FF5A5F (SOS/error), gold #F5C24B (stars).
- Typeface: Schibsted Grotesk (Google Fonts). Tight negative tracking on titles/fares.
- Wordmark: lowercase "liive" + aqua pulse dot. No gradients. No emoji. Functional color only.
- Icons: iOS = SF Symbols, Android = Material Symbols (Rounded). See assets/icon-map.md
  for the SF Symbol names. Never ship the web mockup's Lucide icons.

WHAT TO BUILD:
1. A design-system module per platform from the drop-in tokens + the component inventory
   in SPEC.md §6 (Button, Badge, IconCircle, Avatar, RatingStars, Card, ListRow,
   SegmentedControl, Switch, Stepper, GlassPanel, BottomSheet, SOSButton, ProgressDots,
   MapMarker, DriverCard, FareRow). Reference each component's .d.ts + .prompt.md.
2. The rider flow as a persisted state machine: destination → options → matching →
   enroute → complete (SPEC.md §7). Match ui_kits/liive-ride/ screen-for-screen.
   Pool tier must demonstrate the 2-leg multi-hop journey with a transfer point.
3. A mock service (per platform) implementing the ride Service protocol so the entire
   flow runs offline. Stub Mapbox/LiveKit/Radar/Stripe behind protocols (SPEC.md §8);
   wire live implementations later.

ARCHITECTURE:
- iOS: modular SPM (RideSharingFeature + RideSharingService), MVVM + Combine + async/await,
  @Published state enum + single handle(event:), DI via initializers, coordinator nav.
- Android: feature module, MVVM/MVI with StateFlow<UiState> + onEvent(Event), Hilt, Nav-Compose.
- Mirror the two state machines 1:1.

ACCEPTANCE (SPEC.md §9):
- iOS and Android are visually indistinguishable and match ui_kits/liive-ride/.
- Dark mode pixel-correct; light mode via the provided light tokens.
- Zero raw hex / magic numbers in feature code — semantic tokens only.
- Full flow runs against the mock service with no backend.
- Schibsted Grotesk renders on both; fares/ETAs use tabular figures.

Start by reading handoff/SPEC.md and the token files, then scaffold both design-system
modules, then build the screens. Ask before adding any screen, field, or copy not present
in the design system.
```

---

### Notes for you (not Codex)
- Make sure the design-system folder (this project) and `liive-ios/` are both in the repo
  Codex can see, at the paths referenced above. If they live elsewhere, update the paths
  in the command.
- The token files are **ready to compile**; the `.prompt.md` + `.d.ts` files give Codex the
  exact props/variants for the remaining components.
- If you only want one platform first, delete the other platform's lines from "USE THE
  PRE-TRANSLATED TOKENS", "WHAT TO BUILD", and "ARCHITECTURE".
