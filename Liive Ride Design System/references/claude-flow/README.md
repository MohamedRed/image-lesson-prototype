# Claude Design / Liive Ride flow references

These reference captures are the source-of-truth visual target for the standalone Liive Ride native iOS and Android apps.

## Flow states

1. `01-destination.jpg` — map-first destination picker with bottom sheet, search field, saved places, and location control.
2. `02-options-pool.jpg` — ride options sheet with Pool selected, 2-leg badge, passenger/bag steppers, female-only pool and child-seat toggles, and `Confirm Pickup · $9.50` CTA.
3. `03-matching.jpg` — matching state with route, pickup/transfer/destination markers, `Finding your driver...`, curb-reserved chip, and cancel CTA.
4. `04-enroute-compact.jpg` — enroute state with voice connected, mic/location controls, SOS, route markers, driver card, multi-leg progress, message and cancel actions.
5. `05-enroute-expanded.jpg` — enroute state with the car marker moved along leg 2 while preserving the multi-leg card and action layout.
6. `06-payment.jpg` — arrived/payment state with fare breakdown for the Pool fare: ride fare `$8.74`, tax/fees `$0.76`, cost-share credit `-$2.00`, total `$9.50`, Apple Pay row, rating prompt, `Pay $9.50`, and Stripe trust copy.
7. `07-receipt.jpg` — paid receipt state with `Thanks for riding`, `$9.50 paid to John · receipt sent`, and `Done` CTA.
8. `08-sos-confirmation.jpg` — dimmed enroute background with Emergency Alert modal, destructive `Call Emergency Services` CTA, and Cancel.

## Native parity requirements

- Pool is the canonical visual path for these references; options/payment/receipt previews should use the Pool fare and multi-leg trip copy.
- SOS must be represented as an explicit confirmation modal. It must not silently call emergency services in preview/demo mode.
- Payment success must only be shown after a successful payment service call in interactive flows. Preview fixtures may render the paid state, but runtime failure must show service-required copy.
- Both platforms should produce visual artifacts covering this state set before product-ready claims.
