import SwiftUI
import MapboxMaps
import AccommodationsService
import CoreLocation

struct SearchMapView: View {
    let properties: [AccommodationProperty]
    let onPropertyTap: (AccommodationProperty) -> Void
    
    @State private var mapView = MapView()
    @State private var selectedProperty: AccommodationProperty?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            MapViewRepresentable(
                properties: properties,
                selectedProperty: $selectedProperty,
                onPropertyTap: onPropertyTap
            )
            .ignoresSafeArea()
            
            if let selectedProperty = selectedProperty {
                PropertyMapCard(property: selectedProperty) {
                    onPropertyTap(selectedProperty)
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: selectedProperty)
    }
}

// MARK: - MapView Representable

struct MapViewRepresentable: UIViewRepresentable {
    let properties: [AccommodationProperty]
    @Binding var selectedProperty: AccommodationProperty?
    let onPropertyTap: (AccommodationProperty) -> Void
    
    func makeUIView(context: Context) -> MapView {
        let mapView = MapView(frame: .zero)
        
        // Configure map style
        mapView.mapboxMap.styleURI = .streets
        
        // Add property annotations
        addPropertyAnnotations(to: mapView)
        
        // Fit to show all properties
        if !properties.isEmpty {
            fitMapToProperties(mapView)
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MapView, context: Context) {
        // Update annotations when properties change
        addPropertyAnnotations(to: mapView)
        
        if !properties.isEmpty {
            fitMapToProperties(mapView)
        }
    }
    
    private func addPropertyAnnotations(to mapView: MapView) {
        // Remove existing annotations
        try? mapView.mapboxMap.removeLayer(withId: "property-symbols")
        try? mapView.mapboxMap.removeSource(withId: "property-source")
        
        // Create GeoJSON source with property data
        var features: [Feature] = []
        
        for property in properties {
            let coordinate = CLLocationCoordinate2D(
                latitude: property.coordinates.latitude,
                longitude: property.coordinates.longitude
            )
            
            var feature = Feature(geometry: Point(coordinate))
            let minPrice = property.priceRange.map { NSDecimalNumber(decimal: $0.min).doubleValue } ?? 0
            feature.properties = [
                "id": .string(property.id),
                "name": .string(property.name),
                "price": .number(minPrice),
                "rating": .number(property.rating ?? 0)
            ]
            features.append(feature)
        }
        
        var geoJSONSource = GeoJSONSource(id: "property-source")
        geoJSONSource.data = .featureCollection(FeatureCollection(features: features))
        
        try? mapView.mapboxMap.addSource(geoJSONSource)
        
        // Create symbol layer for property markers
        var symbolLayer = SymbolLayer(id: "property-symbols", source: "property-source")
        symbolLayer.iconImage = .constant(.name("accommodation-pin"))
        symbolLayer.iconSize = .constant(0.8)
        symbolLayer.iconAnchor = .constant(.bottom)
        symbolLayer.textField = .expression(
            Exp(.format) {
                Exp(.concat) {
                    "$"
                    Exp(.get) { "price" }
                }
                FormatOptions(fontScale: .constant(0.8))
            }
        )
        symbolLayer.textFont = .constant(["DIN Pro Medium", "Arial Unicode MS Regular"])
        symbolLayer.textSize = .constant(12)
        symbolLayer.textColor = .constant(StyleColor(.white))
        symbolLayer.textHaloColor = .constant(StyleColor(.black))
        symbolLayer.textHaloWidth = .constant(1)
        symbolLayer.textOffset = .constant([0, -2])
        symbolLayer.textAnchor = .constant(.bottom)
        
        try? mapView.mapboxMap.addLayer(symbolLayer)
        
        // Add tap gesture for property selection
        _ = mapView.gestures.onMapTap.observe { [weak mapView] context in
            guard let mapView = mapView else { return }
            let coord = mapView.mapboxMap.coordinate(for: context.point)
            
            // Find nearest property to tap coordinate
            let nearest = properties.min(by: { a, b in
                let daLat = a.coordinates.latitude - coord.latitude
                let daLng = a.coordinates.longitude - coord.longitude
                let dbLat = b.coordinates.latitude - coord.latitude
                let dbLng = b.coordinates.longitude - coord.longitude
                let da = daLat * daLat + daLng * daLng
                let db = dbLat * dbLat + dbLng * dbLng
                return da < db
            })
            DispatchQueue.main.async {
                selectedProperty = nearest
            }
        }
    }
    
    private func fitMapToProperties(_ mapView: MapView) {
        let coordinates = properties.map {
            CLLocationCoordinate2D(
                latitude: $0.coordinates.latitude,
                longitude: $0.coordinates.longitude
            )
        }
        
        guard !coordinates.isEmpty else { return }
        
        // Calculate bounding box
        let lats = coordinates.map { $0.latitude }
        let lngs = coordinates.map { $0.longitude }
        
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLng = lngs.min()!
        let maxLng = lngs.max()!
        
        let sw = CLLocationCoordinate2D(latitude: minLat, longitude: minLng)
        let ne = CLLocationCoordinate2D(latitude: maxLat, longitude: maxLng)
        
        let boundingBox = CoordinateBounds(southwest: sw, northeast: ne)
        
        let padding = UIEdgeInsets(top: 50, left: 50, bottom: 100, right: 50)
        try? mapView.mapboxMap.setCameraBounds(with: CameraBoundsOptions(bounds: boundingBox))
        
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0, longitude: (minLng + maxLng) / 2.0)
        mapView.mapboxMap.setCamera(to: CameraOptions(center: center, padding: padding, zoom: 8.0))
    }
}

// MARK: - Property Map Card

struct PropertyMapCard: View {
    let property: AccommodationProperty
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Property image
                AsyncImage(url: URL(string: property.photos.first?.url ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 80, height: 80)
                .clipped()
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(property.name)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        if let rating = property.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text(String(format: "%.1f", rating))
                                    .font(.caption)
                            }
                        }
                        
                        Spacer()
                        
                        if let priceRange = property.priceRange {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("$\(NSDecimalNumber(decimal: priceRange.min).intValue)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("per night")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Text(property.address.city)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SearchMapView(
        properties: [
            // Sample property for preview
        ],
        onPropertyTap: { _ in }
    )
}