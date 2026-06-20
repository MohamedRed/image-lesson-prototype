import SwiftUI
import AITutorService

public struct AITutorContainerView: View {
    let useRealService: Bool
    
    public init(useRealService: Bool) {
        self.useRealService = useRealService
    }
    
    public var body: some View {
        Group {
            if useRealService {
                AITutorMainView(service: AITutorService())
            } else {
                AITutorMainView(service: MockAITutorService())
            }
        }
    }
}