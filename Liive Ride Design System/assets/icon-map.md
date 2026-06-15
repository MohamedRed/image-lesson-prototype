# SF Symbol → Lucide mapping (web mockup substitution)

The Liive Ride app uses **SF Symbols** natively. SF Symbols can't be embedded on the
web, so mockups in this design system use **Lucide** (https://lucide.dev) via CDN.
This table maps each SF Symbol used in the ride feature to its closest Lucide name.

> This is an approximation, not a pixel match. Lucide default: stroke-width 2, size 24, currentColor.

| Purpose | SF Symbol (real app) | Lucide (web) |
|---|---|---|
| Car / driver marker | `car.fill` | `car` |
| Current location | `location.circle.fill` / `location.fill` | `locate-fixed` / `navigation` |
| Walking / walk segment | `figure.walk` / `figure.walk.circle` | `footprints` |
| Pickup / destination pin | `mappin.circle.fill` | `map-pin` |
| Map | `map.fill` | `map` |
| Transfer (swap legs) | `arrow.triangle.swap` | `arrow-left-right` |
| Transfer (circular) | `arrow.triangle.2.circlepath` | `repeat` |
| Mic on / off | `mic.fill` / `mic.slash.fill` | `mic` / `mic-off` |
| Speaker off | `speaker.slash.fill` | `volume-x` |
| Credit card | `creditcard.fill` | `credit-card` |
| Apple Pay | `applelogo` | `apple` |
| Link pay | `link` | `link` |
| Clock / ETA | `clock.circle` | `clock` |
| Settings | `gearshape.fill` | `settings` |
| Warning / error | `exclamationmark.triangle.fill` | `triangle-alert` |
| Live connection | `antenna.radiowaves.left.and.right` | `radio` |
| Demo / play | `play.circle` | `play` |
| Seats / passengers | `person.2.fill` | `users` |
| Luggage | `suitcase.fill` | `luggage` |
| Pet | `pawprint.fill` | `paw-print` |
| Child seat | `figure.child` | `baby` |
| Premium / star | `star.fill` | `star` |
| Shield / safety pool | `shield.lefthalf.filled` | `shield` |
| Chevron | `chevron.right` | `chevron-right` |
| Phone | `phone.fill` | `phone` |
| Message | `message.fill` | `message-circle` |

## Usage

```html
<script src="https://unpkg.com/lucide@latest"></script>
<i data-lucide="car"></i>
<script>lucide.createIcons();</script>
```

Size & color via CSS on the `<svg>` (Lucide renders an inline SVG):
`[data-lucide] { width: 22px; height: 22px; stroke-width: 2; color: var(--accent); }`
