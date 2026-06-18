import SwiftUI

public struct RideSharingView: View {
    @StateObject private var viewModel: RideSharingViewModel
    private let preferredColorScheme: ColorScheme?

    public init(
        service: RideSharingServicing,
        preferredColorScheme: ColorScheme? = .dark,
        initialState: RideUIState? = nil
    ) {
        LiiveFontRegistrar.registerBundledFonts()
        self.preferredColorScheme = preferredColorScheme
        _viewModel = StateObject(wrappedValue: RideSharingViewModel(service: service, initialState: initialState))
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            RideMapCanvasView(
                phase: viewModel.state.phase,
                isMultiLeg: viewModel.state.config.isMultiLeg,
                carProgress: viewModel.state.carProgress,
                destinationName: viewModel.state.config.destinationName,
                tripSummary: viewModel.state.tripSummary
            )
            .ignoresSafeArea()
            .accessibilityIdentifier(RideAccessibilityIdentifier.map)

            if viewModel.state.phase == .complete {
                LiiveColor.scrimSubtle
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            VStack {
                RideChromeView(
                    state: viewModel.state,
                    onLocate: { viewModel.handle(.locate) },
                    onToggleMic: { viewModel.handle(.toggleMic) }
                )
                Spacer()
            }

            if let notice = viewModel.state.actionNotice {
                VStack {
                    RideActionNoticeBanner(notice: notice) {
                        viewModel.handle(.dismissActionNotice)
                    }
                    .padding(.top, RideChromeLayout.noticeTopInset)
                    .padding(.horizontal, RideChromeLayout.horizontalPadding)
                    Spacer()
                }
                .transition(.opacity)
            }

            if viewModel.state.phase == .matching || viewModel.state.phase == .enroute {
                VStack {
                    HStack {
                        Spacer()
                        LiiveSOSButton(size: RideChromeLayout.sosSize, showLabel: false) {
                            viewModel.handle(.presentSOS(true))
                        }
                        .padding(.trailing, RideChromeLayout.sosTrailingPadding)
                        .padding(.top, RideChromeLayout.sosTopInset)
                        .accessibilityIdentifier(RideAccessibilityIdentifier.sosButton)
                    }
                    Spacer()
                }
            }

            bottomSheet

            if viewModel.state.isSOSPresented {
                RideSOSConfirmationView(
                    onEmergency: { viewModel.handle(.presentSOS(false)) },
                    onCancel: { viewModel.handle(.presentSOS(false)) }
                )
                .transition(.opacity)
            }
        }
        .background(LiiveColor.bg)
        .preferredColorScheme(preferredColorScheme)
        .animation(.easeInOut(duration: LiiveMotion.base), value: viewModel.state.phase)
        .accessibilityIdentifier(RideAccessibilityIdentifier.root)
    }

    @ViewBuilder
    private var bottomSheet: some View {
        switch viewModel.state.phase {
        case .destination:
            RideDestinationSheetView(viewModel: viewModel)
        case .options:
            RideOptionsSheetView(viewModel: viewModel)
        case .matching:
            RideMatchingSheetView(viewModel: viewModel)
        case .enroute:
            RideEnrouteSheetView(viewModel: viewModel)
        case .complete:
            RideCompleteSheetView(viewModel: viewModel)
        }
    }
}

private struct RideActionNoticeBanner: View {
    let notice: RideActionNotice
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            LiiveGlassPanel(material: .thin, cornerRadius: LiiveRadius.xl, padding: 0) {
                VStack(alignment: .leading, spacing: RideChromeLayout.noticeTextGap) {
                    Text(notice.title)
                        .font(LiiveFont.subhead.weight(.semibold))
                        .foregroundColor(LiiveColor.text)
                    Text(notice.message)
                        .font(LiiveFont.footnote)
                        .foregroundColor(LiiveColor.textSecondary)
                }
                .padding(RideChromeLayout.noticePanelPadding)
                .frame(maxWidth: RideChromeLayout.noticeMaxWidth, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss ride notice")
    }
}

struct RideSharingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            preview("Dark 1 Destination", state: RidePreviewStates.destination, scheme: .dark)
            preview("Dark 2 Options", state: RidePreviewStates.options, scheme: .dark)
            preview("Dark 3 Matching", state: RidePreviewStates.matching, scheme: .dark)
            preview("Dark 4 Enroute", state: RidePreviewStates.enroute, scheme: .dark)
            preview("Dark 5 Payment", state: RidePreviewStates.payment, scheme: .dark)
            preview("Dark 6 Receipt", state: RidePreviewStates.receipt, scheme: .dark)
            preview("Light 1 Destination", state: RidePreviewStates.destination, scheme: .light)
            preview("Light 2 Options", state: RidePreviewStates.options, scheme: .light)
            preview("Light 3 Matching", state: RidePreviewStates.matching, scheme: .light)
            preview("Light 4 Enroute", state: RidePreviewStates.enroute, scheme: .light)
            preview("Light 5 Payment", state: RidePreviewStates.payment, scheme: .light)
            preview("Light 6 Receipt", state: RidePreviewStates.receipt, scheme: .light)
        }
    }

    private static func preview(_ name: String, state: RideUIState, scheme: ColorScheme) -> some View {
        RideSharingView(service: MockRideSharingService(), preferredColorScheme: scheme, initialState: state)
            .previewDisplayName(name)
    }
}
