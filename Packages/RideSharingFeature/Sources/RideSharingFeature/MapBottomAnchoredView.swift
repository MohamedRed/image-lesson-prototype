import SwiftUI

struct MapBottomAnchoredView<Content: View>: View {
    let position: CGPoint
    let content: Content
    @State private var contentSize: CGSize = .zero

    init(position: CGPoint, @ViewBuilder content: () -> Content) {
        self.position = position
        self.content = content()
    }

    var body: some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: MapMarkerSizePreferenceKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(MapMarkerSizePreferenceKey.self) { size in
                contentSize = size
            }
            .position(x: position.x, y: position.y - contentSize.height / 2)
    }
}

private struct MapMarkerSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
