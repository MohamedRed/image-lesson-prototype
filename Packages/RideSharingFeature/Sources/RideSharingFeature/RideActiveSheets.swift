import SwiftUI

struct RideMatchingSheetView: View {
    @ObservedObject var viewModel: RideSharingViewModel
    @State private var animate = false

    private var config: RideConfiguration { viewModel.state.config }

    var body: some View {
        LiiveBottomSheet {
            VStack(spacing: RideSheetLayout.stackedSpacing) {
                HStack(spacing: RideSheetLayout.inlineGap) {
                    ForEach(0..<RideSheetLayout.matchingDotCount, id: \.self) { index in
                        Circle()
                            .fill(LiiveColor.accent)
                            .frame(width: RideSheetLayout.matchingDotSize, height: RideSheetLayout.matchingDotSize)
                            .offset(y: animate ? RideSheetLayout.matchingDotLift : 0)
                            .opacity(animate ? 1 : 0.5)
                            .animation(
                                .easeInOut(duration: RideSheetLayout.matchingDotDuration)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * RideSheetLayout.matchingDotDelay),
                                value: animate
                            )
                    }
                }
                .padding(.bottom, LiiveSpacing.l)

                Text("Finding your driver…")
                    .liiveStyle(.title3)
                    .foregroundColor(LiiveColor.text)
                Text("Matching you with a nearby\(config.femaleOnly ? " female-only" : "") \(config.tier.rawValue) driver and reserving a legal curb.")
                    .font(LiiveFont.sheetMeta)
                    .foregroundColor(LiiveColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: RideSheetLayout.matchingDescriptionMaxWidth)
                    .padding(.top, RideSheetLayout.inlineGap)

                HStack(spacing: RideSheetLayout.controlGap) {
                    LiiveBadge("Curb reserved", color: .success, dot: true)
                    if config.femaleOnly {
                        LiiveBadge("Female-only pool", color: .accent)
                    }
                }
                .padding(.top, LiiveSpacing.l)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, RideSheetLayout.matchingContentTopPadding)
            .padding(.bottom, RideSheetLayout.matchingContentBottomPadding)

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
                    .font(LiiveFont.sheetMeta)
                    .foregroundColor(LiiveColor.textSecondary)
            }
            .padding(.bottom, RideSheetLayout.headerBottomPadding)

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

            HStack(spacing: RideSheetLayout.rowGap) {
                LiiveButton("Message", variant: .secondary, size: .lg, fullWidth: true, icon: Image(systemName: "message.fill")) {}
                LiiveButton("Cancel Ride", variant: .destructivePlain, size: .lg, fullWidth: true) {
                    viewModel.handle(.cancelRide)
                }
            }
            .padding(.top, RideSheetLayout.sectionGap)
        }
        .accessibilityIdentifier(RideAccessibilityIdentifier.enrouteSheet)
    }

    private func multiLegPanel(transferStatus: String) -> some View {
        VStack(alignment: .leading, spacing: RideSheetLayout.rowGap) {
            HStack(spacing: RideSheetLayout.controlGap) {
                Image(systemName: "map.fill")
                    .font(.system(size: RideSheetLayout.multiLegIconSize, weight: .semibold))
                    .foregroundColor(LiiveColor.accent)
                Text("Multi-leg journey")
                    .font(LiiveFont.subhead.weight(.semibold))
                    .foregroundColor(LiiveColor.text)
            }
            LiiveProgressDots(legs: 2, current: 2)
            Rectangle()
                .fill(LiiveColor.separator)
                .frame(height: RideSheetLayout.hairlineHeight)
                .padding(.top, RideSheetLayout.transferSeparatorTopPadding)
            HStack(spacing: RideSheetLayout.inlineGap) {
                Image(systemName: "figure.walk")
                    .font(.system(size: RideSheetLayout.transferIconSize, weight: .semibold))
                    .foregroundColor(LiiveColor.warning)
                Text(transferStatus)
                    .font(LiiveFont.footnote)
                    .foregroundColor(LiiveColor.textSecondary)
            }
        }
        .padding(RideSheetLayout.multiLegPanelPadding)
        .background(LiiveColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
        .padding(.top, RideSheetLayout.multiLegPanelTopPadding)
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
            VStack(spacing: RideSheetLayout.stackedSpacing) {
                LiiveIconCircle(systemName: "checkmark", color: .success, size: RideSheetLayout.receiptIconSize, filled: true)
                Text("Thanks for riding")
                    .liiveStyle(.title2)
                    .foregroundColor(LiiveColor.text)
                    .padding(.top, RideSheetLayout.sectionGap)
                Text("\(fare.total.ridePrice) paid to \(driver.firstName) · receipt sent")
                    .font(LiiveFont.subhead.monospacedDigit())
                    .foregroundColor(LiiveColor.textSecondary)
                    .padding(.top, RideSheetLayout.inlineGap)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, RideSheetLayout.receiptContentVerticalPadding)

            LiiveButton("Done", variant: .primary, size: .lg, shape: .capsule, fullWidth: true) {
                viewModel.handle(.reset)
            }
            .padding(.top, RideSheetLayout.receiptButtonTopPadding)
        }
        .accessibilityIdentifier(RideAccessibilityIdentifier.receiptSheet)
    }

    private var paymentSheet: some View {
        LiiveBottomSheet {
            HStack(spacing: RideSheetLayout.rowGap) {
                LiiveIconCircle(systemName: "flag.fill", color: .success, size: RideSheetLayout.paymentStatusIconSize, filled: true)
                VStack(alignment: .leading, spacing: RideSheetLayout.compactGap) {
                    Text("You've arrived")
                        .liiveStyle(.title3)
                        .foregroundColor(LiiveColor.text)
                    Text("\(config.destinationName) · \(trip.completedDuration) · \(trip.completedDistance)")
                        .font(LiiveFont.footnote.monospacedDigit())
                        .foregroundColor(LiiveColor.textSecondary)
                }
                Spacer()
            }
            .padding(.bottom, RideSheetLayout.sectionGap)

            VStack(spacing: RideSheetLayout.stackedSpacing) {
                LiiveFareRow(label: "Ride fare", amount: fare.rideFare.ridePrice)
                LiiveFareRow(label: "Tax & fees", amount: fare.taxAndFees.ridePrice)
                if let credit = fare.costShareCredit {
                    LiiveFareRow(label: "Cost-share credit", amount: "–\(credit.ridePrice)", muted: true)
                }
                Rectangle()
                    .fill(LiiveColor.separator)
                    .frame(height: RideSheetLayout.hairlineHeight)
                LiiveFareRow(label: "Total", amount: fare.total.ridePrice, total: true)
            }
            .padding(.horizontal, RideSheetLayout.fareCardHorizontalPadding)
            .padding(.top, RideSheetLayout.fareCardTopPadding)
            .padding(.bottom, RideSheetLayout.fareCardBottomPadding)
            .background(LiiveColor.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
            .padding(.bottom, RideSheetLayout.paymentSectionGap)

            VStack(spacing: RideSheetLayout.stackedSpacing) {
                LiiveListRow(title: "Apple Pay", value: "default", divider: false, chevron: true) {
                    LiiveIconCircle(systemName: "applelogo", color: .neutral, size: RideSheetLayout.optionIconSize)
                }
            }
            .background(LiiveColor.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
            .padding(.bottom, RideSheetLayout.paymentSectionGap)

            ratingControl
            LiiveButton("Pay \(fare.total.ridePrice)", variant: .primary, size: .lg, shape: .capsule, fullWidth: true, tabularNumbers: true) {
                viewModel.handle(.pay)
            }
            Text("Secured by Stripe")
                .font(LiiveFont.caption1)
                .foregroundColor(LiiveColor.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, RideSheetLayout.securityCopyTopPadding)
        }
        .accessibilityIdentifier(RideAccessibilityIdentifier.paymentSheet)
    }

    private var ratingControl: some View {
        VStack(spacing: RideSheetLayout.controlGap) {
            Text("Rate your driver")
                .font(LiiveFont.sheetMeta)
                .foregroundColor(LiiveColor.textSecondary)
            HStack(spacing: RideSheetLayout.inlineGap) {
                ForEach(1...5, id: \.self) { value in
                    Button(action: { viewModel.handle(.rate(value)) }) {
                        Image(systemName: "star.fill")
                            .font(.system(size: RideSheetLayout.ratingStarSize))
                            .foregroundColor(value <= viewModel.state.rating ? LiiveColor.star : LiiveColor.fill)
                            .padding(RideSheetLayout.ratingStarPadding)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, RideSheetLayout.ratingBottomPadding)
    }
}

private extension RideDriver {
    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}
