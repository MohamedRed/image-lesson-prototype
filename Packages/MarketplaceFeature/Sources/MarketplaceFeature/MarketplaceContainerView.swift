import SwiftUI
import MarketplaceService

/// Container view for easy integration with the main Liive app
/// Provides a simple entry point with all dependencies configured
public struct MarketplaceContainerView: View {
    
    public init() {}
    
    public var body: some View {
        MarketplaceRootView()
    }
}

/// Preview-friendly version for Xcode previews
public struct MarketplacePreview: View {
    
    public init() {}
    
    public var body: some View {
        MarketplaceRootView(service: MockMarketplaceService())
            .preferredColorScheme(.light)
    }
}

#Preview("Marketplace - Light Mode") {
    MarketplacePreview()
}

#Preview("Marketplace - Dark Mode") {
    MarketplacePreview()
        .preferredColorScheme(.dark)
}