# Liive Ride — Rider App UI kit

An interactive, high-fidelity recreation of the **Liive Ride** rider flow, built entirely from this design system's component primitives. Open `index.html`.

## The flow
1. **Where to?** — current-location map, search field, saved places (Home / Work / recents).
2. **Choose your ride** — Pool / Premium / Exclusive tiers, female-only safety pool, passenger + bag steppers, child-seat toggle, fare estimate.
3. **Finding your driver…** — curb-reservation + pool matching state.
4. **Live ride** — driver card (name, rating, vehicle, plate, ETA), animated car on the route, voice-connected HUD + mic, floating SOS, and the multi-leg journey panel when Pool routes through a transfer.
5. **Trip complete & pay** — Stripe fare breakdown, Apple Pay, star rating, pay → receipt.

> Choosing **Pool** demonstrates the distinctive **multi-leg journey** (2 legs + a transfer point); Premium/Exclusive are single-leg.

## Composition
- Device bezel: `ios-frame.jsx` (starter component).
- `MapCanvas.jsx` — the persistent stylised dark map (SVG roads, route line, DS `MapMarker`s).
- `screens1.jsx` / `screens2.jsx` — the five `BottomSheet` screens.
- `RideApp.jsx` — state machine, persistent map, top glass HUD, SOS, sheet routing; state persists to `localStorage`.

Every control (buttons, steppers, switches, segmented control, driver card, badges, progress dots, fare rows, SOS) comes from `window.LiiveRideDesignSystem_b6f128` via `_ds_bundle.js`. The map background and live tiles are stylised stand-ins, not real Mapbox.
