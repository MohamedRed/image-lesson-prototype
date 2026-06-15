---
name: liive-ride-design
description: Use this skill to generate well-branded interfaces and assets for Liive Ride, either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files.
If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and create static HTML files for the user to view. If working on production code, you can copy assets and read the rules here to become an expert in designing with this brand.
If the user invokes this skill without any other guidance, ask them what they want to build or design, ask some questions, and act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.

## Quick map of this design system
- `readme.md` — the full design guide: product context, content & visual foundations, iconography, caveats.
- `styles.css` — single global entry point (link this; it `@import`s every token + base file).
- `tokens/` — palette (iOS system colors), semantic aliases (dark-first), typography, spacing, effects.
- `assets/` — `wordmark.css` (typographic Liive lockup) and `icon-map.md` (SF Symbol → Lucide).
- `guidelines/` — foundation specimen cards (Type / Colors / Spacing / Brand).
- `components/core/` + `components/ride/` — React primitives; consume via `window.LiiveRideDesignSystem_b6f128` after loading `_ds_bundle.js`.
- `ui_kits/liive-ride/` — interactive recreation of the rider app (destination → options → match → live ride → pay).
- `templates/ride-screen/` — a copy-ready starter screen.

## The essentials
- **Brand: "TIDE"** — premium, minimal, intentionally designed (the original app UI was an un-designed prototype; this identity replaces it).
- **Dark-mode first.** The app lives on a dark map; anchor to dark (`--bg` `#07121A`), light is opt-in via `[data-theme="light"]`.
- **Accent = luminous aqua** (`--accent` `#54E0C6`). Status hues are semantic: mint = connected/paid, amber = transfers/walk/surge, coral = SOS/error.
- **Type: Schibsted Grotesk** (bundled webfont via `tokens/fonts.css`). Display weight + tight negative tracking for titles/fares/wordmark.
- **Look:** cool-ink surfaces, capsule pills, frosted-glass HUD panels over the map, soft downward shadows, 12–16px card radii. Wordmark = lowercase `liive` + aqua pulse dot.
- **Icons:** Lucide via CDN (the production iOS app uses SF Symbols; mapping in `assets/icon-map.md`).
- **Tone:** plain, reassuring, "we"/"you", Title Case headings, no emoji in chrome.
