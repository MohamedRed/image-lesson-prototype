import SwiftUI

public struct RideSharingView: View {
    @StateObject private var viewModel: RideSharingViewModel

    public init(service: RideSharingServicing = MockRideSharingService()) {
        _viewModel = StateObject(wrappedValue: RideSharingViewModel(service: service))
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            RideMapCanvasView(
                phase: viewModel.state.phase,
                isMultiLeg: viewModel.state.config.isMultiLeg,
                carProgress: viewModel.state.carProgress
            )
            .ignoresSafeArea()

            if viewModel.state.phase == .complete {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            VStack {
                RideChromeView(
                    state: viewModel.state,
                    onLocate: {},
                    onToggleMic: { viewModel.handle(.toggleMic) }
                )
                Spacer()
            }

            if viewModel.state.phase == .matching || viewModel.state.phase == .enroute {
                VStack {
                    HStack {
                        Spacer()
                        LiiveSOSButton(size: 54, showLabel: false) {
                            viewModel.handle(.presentSOS(true))
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 116)
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
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: LiiveMotion.base), value: viewModel.state.phase)
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

struct RideSharingView_Previews: PreviewProvider {
    static var previews: some View {
        RideSharingView()
    }
}
