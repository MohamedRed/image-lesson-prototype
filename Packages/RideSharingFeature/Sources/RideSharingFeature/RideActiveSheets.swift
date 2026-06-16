import SwiftUI

struct RideMatchingSheetView: View {
    @ObservedObject var viewModel: RideSharingViewModel
    @State private var animate = false

    private var config: RideConfiguration { viewModel.state.config }

    var body: some View {
        LiiveBottomSheet {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(LiiveColor.accent)
                            .frame(width: 9, height: 9)
                            .offset(y: animate ? -7 : 0)
                            .opacity(animate ? 1 : 0.5)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.16),
                                value: animate
                            )
                    }
                }
                .padding(.bottom, 16)

                Text("Finding your driver…")
                    .liiveStyle(.title3)
                    .foregroundColor(LiiveColor.text)
                Text("Matching you with a nearby\(config.femaleOnly ? " female-only" : "") \(config.tier.rawValue) driver and reserving a legal curb.")
                    .font(Font.custom(LiiveFont.family, size: 14))
                    .foregroundColor(LiiveColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                    .padding(.top, 6)

                HStack(spacing: 8) {
                    LiiveBadge("Curb reserved", color: .success, dot: true)
                    if config.femaleOnly {
                        LiiveBadge("Female-only pool", color: .accent)
                    }
                }
                .padding(.top, 16)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 22)

            LiiveButton("Cancel", variant: .secondary, size: .lg, shape: .capsule, fullWidth: true) {
                viewModel.handle(.cancelMatching)
            }
        }
        .onAppear { animate = true }
    }
}

struct RideEnrouteSheetView: View {
    @ObservedObject var viewModel: RideSharingViewModel

    private var config: RideConfiguration { viewModel.state.config }

    var body: some View {
        LiiveBottomSheet {
            HStack(alignment: .firstTextBaseline) {
                Text(config.isMultiLeg ? "On leg 2 of 2" : "Your driver is arriving")
                    .liiveStyle(.title3)
                    .foregroundColor(LiiveColor.text)
                Spacer()
                Text("to \(config.destinationName)")
                    .font(Font.custom(LiiveFont.family, size: 14))
                    .foregroundColor(LiiveColor.textSecondary)
            }
            .padding(.bottom, 12)

            LiiveDriverCard(
                name: "John Driver",
                rating: 4.8,
                vehicle: "Toyota Camry · Blue",
                plate: "ABC 123",
                eta: config.isMultiLeg ? "3 min" : "4 min",
                speaking: true
            ) {
                LiiveButton(
                    "",
                    variant: .tinted,
                    icon: Image(systemName: "phone.fill"),
                    iconOnly: true,
                    accessibilityLabel: "Call driver"
                ) {}
            }

            if config.isMultiLeg {
                multiLegPanel
            }

            HStack(spacing: 10) {
                LiiveButton("Message", variant: .secondary, size: .lg, fullWidth: true, icon: Image(systemName: "message.fill")) {}
                LiiveButton("Cancel Ride", variant: .destructivePlain, size: .lg, fullWidth: true) {
                    viewModel.handle(.cancelRide)
                }
            }
            .padding(.top, 14)
        }
    }

    private var multiLegPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(LiiveColor.accent)
                Text("Multi-leg journey")
                    .font(LiiveFont.subhead.weight(.semibold))
                    .foregroundColor(LiiveColor.text)
            }
            LiiveProgressDots(legs: 2, current: 2)
            Rectangle()
                .fill(LiiveColor.separator)
                .frame(height: 0.5)
                .padding(.top, 2)
            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(LiiveColor.warning)
                Text("Transfer at Hayes St complete · 150m walk")
                    .font(LiiveFont.footnote)
                    .foregroundColor(LiiveColor.textSecondary)
            }
        }
        .padding(14)
        .background(LiiveColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
        .padding(.top, 12)
    }
}

struct RideCompleteSheetView: View {
    @ObservedObject var viewModel: RideSharingViewModel

    private var config: RideConfiguration { viewModel.state.config }
    private var fare: Double { config.price }
    private var base: Double { (fare / 1.0875 * 100).rounded() / 100 }
    private var tax: Double { ((fare - base) * 100).rounded() / 100 }

    var body: some View {
        if viewModel.state.paid {
            paidReceipt
        } else {
            paymentSheet
        }
    }

    private var paidReceipt: some View {
        LiiveBottomSheet {
            VStack(spacing: 0) {
                LiiveIconCircle(systemName: "checkmark", color: .success, size: 56, filled: true)
                Text("Thanks for riding")
                    .liiveStyle(.title2)
                    .foregroundColor(LiiveColor.text)
                    .padding(.top, 14)
                Text("\(fare.ridePrice) paid to John · receipt sent")
                    .font(LiiveFont.subhead.monospacedDigit())
                    .foregroundColor(LiiveColor.textSecondary)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)

            LiiveButton("Done", variant: .primary, size: .lg, shape: .capsule, fullWidth: true) {
                viewModel.handle(.reset)
            }
            .padding(.top, 20)
        }
    }

    private var paymentSheet: some View {
        LiiveBottomSheet {
            HStack(spacing: 10) {
                LiiveIconCircle(systemName: "flag.fill", color: .success, size: 36, filled: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You've arrived")
                        .liiveStyle(.title3)
                        .foregroundColor(LiiveColor.text)
                    Text("\(config.destinationName) · 18 min · 5.2 km")
                        .font(LiiveFont.footnote.monospacedDigit())
                        .foregroundColor(LiiveColor.textSecondary)
                }
                Spacer()
            }
            .padding(.bottom, 14)

            VStack(spacing: 0) {
                LiiveFareRow(label: "Ride fare", amount: base.ridePrice)
                LiiveFareRow(label: "Tax & fees", amount: tax.ridePrice)
                if config.isMultiLeg {
                    LiiveFareRow(label: "Cost-share credit", amount: "–$2.00", muted: true)
                }
                Rectangle()
                    .fill(LiiveColor.separator)
                    .frame(height: 0.5)
                LiiveFareRow(label: "Total", amount: fare.ridePrice, total: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(LiiveColor.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                LiiveListRow(title: "Apple Pay", value: "default", divider: false, chevron: true) {
                    LiiveIconCircle(systemName: "applelogo", color: .neutral, size: 32)
                }
            }
            .background(LiiveColor.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
            .padding(.bottom, 12)

            ratingControl
            LiiveButton("Pay \(fare.ridePrice)", variant: .primary, size: .lg, shape: .capsule, fullWidth: true, tabularNumbers: true) {
                viewModel.handle(.pay)
            }
            Text("Secured by Stripe")
                .font(LiiveFont.caption1)
                .foregroundColor(LiiveColor.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
    }

    private var ratingControl: some View {
        VStack(spacing: 8) {
            Text("Rate your driver")
                .font(Font.custom(LiiveFont.family, size: 14))
                .foregroundColor(LiiveColor.textSecondary)
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { value in
                    Button(action: { viewModel.handle(.rate(value)) }) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 28))
                            .foregroundColor(value <= viewModel.state.rating ? LiiveColor.star : LiiveColor.fill)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 16)
    }
}
