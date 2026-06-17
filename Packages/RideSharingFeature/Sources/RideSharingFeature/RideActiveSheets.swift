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
        .accessibilityIdentifier(RideAccessibilityIdentifier.matchingSheet)
        .onAppear { animate = true }
    }
}

struct RideEnrouteSheetView: View {
    @ObservedObject var viewModel: RideSharingViewModel

    private var config: RideConfiguration { viewModel.state.config }
    private var driver: RideDriver { viewModel.state.driver }
    private var trip: RideTripSummary { viewModel.state.tripSummary }

    var body: some View {
        LiiveBottomSheet {
            HStack(alignment: .firstTextBaseline) {
                Text(trip.enrouteTitle)
                    .liiveStyle(.title3)
                    .foregroundColor(LiiveColor.text)
                Spacer()
                Text("to \(config.destinationName)")
                    .font(Font.custom(LiiveFont.family, size: 14))
                    .foregroundColor(LiiveColor.textSecondary)
            }
            .padding(.bottom, 12)

            LiiveDriverCard(
                name: driver.name,
                rating: driver.rating,
                vehicle: driver.vehicle,
                plate: driver.plate,
                eta: trip.driverETA,
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

            if let transferStatus = trip.transferStatus {
                multiLegPanel(transferStatus: transferStatus)
            }

            HStack(spacing: 10) {
                LiiveButton("Message", variant: .secondary, size: .lg, fullWidth: true, icon: Image(systemName: "message.fill")) {}
                LiiveButton("Cancel Ride", variant: .destructivePlain, size: .lg, fullWidth: true) {
                    viewModel.handle(.cancelRide)
                }
            }
            .padding(.top, 14)
        }
        .accessibilityIdentifier(RideAccessibilityIdentifier.enrouteSheet)
    }

    private func multiLegPanel(transferStatus: String) -> some View {
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
                Text(transferStatus)
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
    private var driver: RideDriver { viewModel.state.driver }
    private var fare: RideFareBreakdown { config.fareBreakdown }
    private var trip: RideTripSummary { viewModel.state.tripSummary }

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
                Text("\(fare.total.ridePrice) paid to \(driver.firstName) · receipt sent")
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
        .accessibilityIdentifier(RideAccessibilityIdentifier.receiptSheet)
    }

    private var paymentSheet: some View {
        LiiveBottomSheet {
            HStack(spacing: 10) {
                LiiveIconCircle(systemName: "flag.fill", color: .success, size: 36, filled: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You've arrived")
                        .liiveStyle(.title3)
                        .foregroundColor(LiiveColor.text)
                    Text("\(config.destinationName) · \(trip.completedDuration) · \(trip.completedDistance)")
                        .font(LiiveFont.footnote.monospacedDigit())
                        .foregroundColor(LiiveColor.textSecondary)
                }
                Spacer()
            }
            .padding(.bottom, 14)

            VStack(spacing: 0) {
                LiiveFareRow(label: "Ride fare", amount: fare.rideFare.ridePrice)
                LiiveFareRow(label: "Tax & fees", amount: fare.taxAndFees.ridePrice)
                if let credit = fare.costShareCredit {
                    LiiveFareRow(label: "Cost-share credit", amount: "–\(credit.ridePrice)", muted: true)
                }
                Rectangle()
                    .fill(LiiveColor.separator)
                    .frame(height: 0.5)
                LiiveFareRow(label: "Total", amount: fare.total.ridePrice, total: true)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 14)
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
            LiiveButton("Pay \(fare.total.ridePrice)", variant: .primary, size: .lg, shape: .capsule, fullWidth: true, tabularNumbers: true) {
                viewModel.handle(.pay)
            }
            Text("Secured by Stripe")
                .font(LiiveFont.caption1)
                .foregroundColor(LiiveColor.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
        .accessibilityIdentifier(RideAccessibilityIdentifier.paymentSheet)
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
                            .padding(2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 16)
    }
}

private extension RideDriver {
    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}
