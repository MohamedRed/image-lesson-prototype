# handoff/ — Native build package

Everything Codex (or a developer) needs to implement **Liive Ride** as pure-native
**iOS (SwiftUI)** and **Android (Jetpack Compose)** apps, matching the "TIDE" design system.

- **`CODEX_PROMPT.md`** — the paste-ready command for Codex. Start here.
- **`SPEC.md`** — the full build spec: brand, architecture, fonts, iconography, component
  inventory → native, screens/flow, platform SDKs, acceptance criteria.
- **`ios/`** — drop-in SwiftUI tokens (`LiiveColors`, `LiiveTypography`, `LiiveLayout`) plus
  **9 ready components**: `LiiveButton`, `LiiveBadge`, `LiiveIconCircle`, `LiiveAvatar`,
  `LiiveRatingStars`, `LiiveGlassPanel`, `LiiveBottomSheet`, `LiiveSOSButton`, `LiiveDriverCard`.
- **`android/`** — drop-in Compose tokens (`Color.kt`, `Type.kt`, `Dimens.kt`, `Theme.kt`) plus
  the same **9 ready components** (`LiiveSosButton` spelling on Android).

The token files are generated from `../tokens/*.css` and are ready to compile. The web
design system (`../readme.md`, `../components/**`, `../ui_kits/liive-ride/`) remains the
visual source of truth.
