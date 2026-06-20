import SwiftUI
import AccommodationsService

/// Helper functions for accessibility support
public struct AccessibilityHelper {
    
    // MARK: - Property Accessibility
    
    /// Creates accessibility label for property cards
    public static func propertyCardLabel(for property: AccommodationProperty) -> String {
        var components: [String] = []
        
        components.append(property.name)
        components.append("\(property.type.displayName)")
        
        if let rating = property.rating {
            components.append(String(format: "Rated %.1f stars", rating))
        }
        
        let reviewWord = property.reviewsCount == 1 ? "review" : "reviews"
        components.append("\(property.reviewsCount) \(reviewWord)")
        
        if let priceRange = property.priceRange {
            let minInt = NSDecimalNumber(decimal: priceRange.min).intValue
            components.append("From \(minInt) dollars per night")
        }
        
        components.append("Located in \(property.address.formattedAddress)")
        
        return components.joined(separator: ". ")
    }
    
    /// Creates accessibility hint for property cards
    public static func propertyCardHint() -> String {
        "Double tap to view property details"
    }
    
    /// Creates accessibility label for favorite button
    public static func favoriteButtonLabel(isFavorite: Bool) -> String {
        isFavorite ? "Remove from favorites" : "Add to favorites"
    }
    
    /// Creates accessibility hint for favorite button
    public static func favoriteButtonHint(isFavorite: Bool) -> String {
        isFavorite ? "Double tap to remove from your saved properties" : "Double tap to save this property to your favorites"
    }
    
    // MARK: - Booking Accessibility
    
    /// Creates accessibility label for booking progress
    public static func bookingProgressLabel(currentStep: Int, totalSteps: Int, stepName: String) -> String {
        "Step \(currentStep) of \(totalSteps): \(stepName)"
    }
    
    /// Creates accessibility label for guest form
    public static func guestFormLabel(guestIndex: Int, isLead: Bool) -> String {
        if isLead {
            return "Lead guest information form"
        } else {
            return "Guest \(guestIndex + 1) information form"
        }
    }
    
    /// Creates accessibility label for price breakdown
    public static func priceBreakdownLabel(title: String, amount: Double, currency: String, isTotal: Bool = false) -> String {
        let prefix = isTotal ? "Total cost:" : "\(title):"
        return "\(prefix) \(Int(amount)) \(currency)"
    }
    
    // MARK: - Search Accessibility
    
    /// Creates accessibility label for search results
    public static func searchResultsLabel(count: Int, location: String) -> String {
        let propertyWord = count == 1 ? "property" : "properties"
        return "Found \(count) \(propertyWord) in \(location)"
    }
    
    /// Creates accessibility label for date range
    public static func dateRangeLabel(checkIn: Date, checkOut: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let checkInStr = formatter.string(from: checkIn)
        let checkOutStr = formatter.string(from: checkOut)
        
        let nights = Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 0
        let nightWord = nights == 1 ? "night" : "nights"
        
        return "Check in \(checkInStr), check out \(checkOutStr), \(nights) \(nightWord)"
    }
    
    /// Creates accessibility label for guest configuration
    public static func guestConfigurationLabel(adults: Int, children: Int, rooms: Int) -> String {
        var components: [String] = []
        
        let adultWord = adults == 1 ? "adult" : "adults"
        components.append("\(adults) \(adultWord)")
        
        if children > 0 {
            let childWord = children == 1 ? "child" : "children"
            components.append("\(children) \(childWord)")
        }
        
        let roomWord = rooms == 1 ? "room" : "rooms"
        components.append("\(rooms) \(roomWord)")
        
        return components.joined(separator: ", ")
    }
    
    // MARK: - Rating Accessibility
    
    /// Creates accessibility label for star rating
    public static func starRatingLabel(rating: Double) -> String {
        let wholeStars = Int(rating)
        let hasHalfStar = rating - Double(wholeStars) >= 0.5
        
        var description = ""
        
        if wholeStars > 0 {
            let starWord = wholeStars == 1 ? "star" : "stars"
            description += "\(wholeStars) \(starWord)"
        }
        
        if hasHalfStar {
            if !description.isEmpty { description += " and " }
            description += "half star"
        }
        
        if description.isEmpty {
            description = "No rating"
        } else {
            description += " rating"
        }
        
        return description
    }
    
    // MARK: - Filter Accessibility
    
    /// Creates accessibility label for applied filters
    public static func appliedFiltersLabel(filters: SearchFilters) -> String {
        var appliedFilters: [String] = []
        
        if let priceMin = filters.budgetMin, let priceMax = filters.budgetMax {
            let minInt = NSDecimalNumber(decimal: priceMin).intValue
            let maxInt = NSDecimalNumber(decimal: priceMax).intValue
            appliedFilters.append("Price range \(minInt) to \(maxInt) dollars")
        }
        
        if let types = filters.types, !types.isEmpty {
            let typeList = types.map { $0.displayName }.joined(separator: ", ")
            appliedFilters.append("Property types: \(typeList)")
        }
        
        if let amenities = filters.amenities, !amenities.isEmpty {
            let amenityList = amenities.joined(separator: ", ")
            appliedFilters.append("Required amenities: \(amenityList)")
        }
        
        if let minRating = filters.rating, minRating > 0 {
            appliedFilters.append("Minimum rating \(minRating) stars")
        }
        
        if appliedFilters.isEmpty {
            return "No filters applied"
        } else {
            return "Applied filters: " + appliedFilters.joined(separator: "; ")
        }
    }
    
    // MARK: - Photo Gallery Accessibility
    
    /// Creates accessibility label for photo in gallery
    public static func photoGalleryLabel(index: Int, total: Int, caption: String?) -> String {
        var label = "Photo \(index + 1) of \(total)"
        
        if let caption = caption, !caption.isEmpty {
            label += ": \(caption)"
        }
        
        return label
    }
    
    /// Creates accessibility hint for photo in gallery
    public static func photoGalleryHint() -> String {
        "Double tap to zoom, pinch to zoom, drag when zoomed in, swipe up or down to close"
    }
    
    // MARK: - Error and Status Accessibility
    
    /// Creates accessibility label for error states
    public static func errorStateLabel(error: String) -> String {
        "Error: \(error)"
    }
    
    /// Creates accessibility label for loading states
    public static func loadingStateLabel(action: String) -> String {
        "Loading \(action)"
    }
    
    /// Creates accessibility label for empty states
    public static func emptyStateLabel(content: String) -> String {
        "No \(content) found"
    }
    
    // MARK: - Voice Input Accessibility
    
    /// Creates accessibility label for voice input status
    public static func voiceInputStatusLabel(isRecording: Bool, hasTranscription: Bool) -> String {
        if isRecording {
            return "Recording voice input. Speak now."
        } else if hasTranscription {
            return "Voice input recorded. Review transcription or tap search."
        } else {
            return "Voice input ready. Tap microphone to start recording."
        }
    }
    
    // MARK: - Import Booking Accessibility
    
    /// Creates accessibility label for import method selection
    public static func importMethodLabel(method: String, isSelected: Bool) -> String {
        let status = isSelected ? "Selected" : "Not selected"
        return "\(method) import method. \(status)"
    }
    
    /// Creates accessibility hint for import method
    public static func importMethodHint() -> String {
        "Double tap to select this import method"
    }
}

// MARK: - View Extensions for Accessibility

extension View {
    
    /// Applies common accessibility traits for buttons
    public func accessibleButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
    
    /// Applies common accessibility traits for toggles
    public func accessibleToggle(label: String, isOn: Bool, hint: String? = nil) -> some View {
        self
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityHint(hint ?? "Double tap to toggle")
    }
    
    /// Applies common accessibility traits for text fields
    public func accessibleTextField(label: String, value: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value.isEmpty ? "Empty" : value)
            .accessibilityHint(hint ?? "")
    }
    
    /// Applies accessibility traits for headings
    public func accessibleHeading(level: AccessibilityHeadingLevel = .h2) -> some View {
        self
            .accessibilityAddTraits(.isHeader)
            .accessibilityHeading(level)
    }
    
    /// Applies accessibility traits for images
    public func accessibleImage(label: String, isDecorative: Bool = false) -> some View {
        self
            .accessibilityLabel(isDecorative ? "" : label)
            .accessibilityHidden(isDecorative)
    }
    
    /// Applies accessibility for dynamic type support
    public func supportsDynamicType() -> some View {
        self
            .dynamicTypeSize(.xSmall ... .accessibility5)
    }
    
    /// Creates accessibility element for complex views
    public func accessibilityElement(label: String, hint: String? = nil, traits: AccessibilityTraits = []) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
}