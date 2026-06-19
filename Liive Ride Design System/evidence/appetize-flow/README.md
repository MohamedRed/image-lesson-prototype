# Appetize Android flow evidence

Captured from the live Appetize Android preview for Liive Ride.

- Appetize URL: <https://appetize.io/app/4en46xcjwi45sftvmkshktvsua>
- GitHub Actions run: <https://github.com/MohamedRed/image-lesson-prototype/actions/runs/27826127928>
- Commit under test: `abbefd138c0c5cffb9e4d06cd6adedf4a3ece547`
- Device: Pixel 7 / Android 13.0 through Appetize
- Capture date: 2026-06-19

## Evidence files

- `appetize-flow-contact-sheet.png` — all 8 captured Android states.
- `claude-vs-appetize-contact-sheet.png` — side-by-side Claude reference vs Appetize Android capture.
- `01-destination-appetize.png` — destination picker.
- `02-options-pool-appetize.png` — Pool ride options.
- `03-matching-appetize.png` — matching / finding driver.
- `04-enroute-compact-appetize.png` — enroute early/compact state.
- `05-enroute-expanded-appetize.png` — enroute later/expanded route state.
- `06-payment-appetize.png` — arrived / payment state.
- `07-receipt-appetize.png` — paid receipt state.
- `08-sos-confirmation-appetize.png` — SOS confirmation modal.

`*-full-appetize.png` files preserve the full browser/Appetize frame for auditability. The shorter `*-appetize.png` files are cropped around the Pixel device.

## Parity assessment

Status: **close enough to use as live Android preview evidence, with follow-up polish required before calling visual parity complete.**

Covered states:

1. Destination picker — covered.
2. Pool options — covered with Pool selected, 2-leg badge, `$9.50`, passenger/bag controls, female-only and child-seat toggles, and confirm CTA.
3. Matching — covered with route, pickup/transfer/destination markers, finding-driver copy, curb-reserved chip, cancel CTA.
4. Enroute compact — covered with voice chip, mic/location/SOS controls, driver card, multi-leg journey, message and cancel actions.
5. Enroute expanded/later — covered with route progress advanced along leg 2.
6. Payment — covered with Pool fare breakdown, total `$9.50`, rating prompt, pay CTA, and Stripe trust copy.
7. Receipt — covered after successful mock payment.
8. SOS confirmation — covered with dimmed enroute background, destructive emergency-services CTA, and cancel action.

Observed mismatches / risks:

- **Destination copy mismatch:** the Claude references show a `Union Square` map marker but use `to Work` / `Work · 18 min · 5.2 km` in several sheet captions. The Android runtime keeps the destination internally consistent as `Union Square`. This should be resolved as a design/product decision rather than blindly implementing inconsistent copy.
- **Platform payment method:** Android correctly shows `Google Pay`; the Claude reference shows `Apple Pay`. This is acceptable platform adaptation, not a defect.
- **Platform chrome:** Android captures include Android status/navigation bars and Pixel camera cutout, while Claude references are iOS-styled. This is expected for native Android evidence.
- **Typography/spacing scale:** Android is close, but some line breaks and text sizing differ from the iOS-style Claude reference, especially CTA text spacing and compact card text truncation.
- **SOS button label:** Claude reference says `SOS HELP`; Android currently shows `SOS`. Consider updating Android label if exact visual parity is required.

## Next gates

- Decide whether destination copy should be logically consistent (`Union Square`) or should exactly mirror the current Claude screenshots (`Work` text with a `Union Square` marker).
- Polish Android typography/spacing/SOS label if exact visual parity is required.
- Repeat the same Appetize-style interactive capture for iOS simulator preview if/when iOS Appetize upload is added.
