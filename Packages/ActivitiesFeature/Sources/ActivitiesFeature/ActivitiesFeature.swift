// Public interface for the ActivitiesFeature module
@_exported import ActivitiesService

public struct ActivitiesFeature {
    public static let main = ActivitiesFeatureView()
    
    private init() {}
}