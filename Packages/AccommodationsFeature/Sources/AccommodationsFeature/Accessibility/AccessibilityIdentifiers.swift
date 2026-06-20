import Foundation

/// Centralized accessibility identifiers for accommodations feature
public enum AccessibilityIdentifiers {
    
    // MARK: - Search Screen
    public enum Search {
        public static let searchBar = "accommodations_search_bar"
        public static let locationButton = "accommodations_location_button"
        public static let voiceInputButton = "accommodations_voice_input_button"
        public static let datePickerButton = "accommodations_date_picker_button"
        public static let guestPickerButton = "accommodations_guest_picker_button"
        public static let filtersButton = "accommodations_filters_button"
        public static let mapToggleButton = "accommodations_map_toggle_button"
        public static let resultsList = "accommodations_results_list"
        public static let emptyStateView = "accommodations_empty_state"
        public static let loadingView = "accommodations_loading_view"
        
        public static func propertyCard(_ propertyId: String) -> String {
            "accommodations_property_card_\(propertyId)"
        }
        
        public static func propertyFavoriteButton(_ propertyId: String) -> String {
            "accommodations_property_favorite_\(propertyId)"
        }
    }
    
    // MARK: - Property Details Screen
    public enum PropertyDetails {
        public static let photoGallery = "property_details_photo_gallery"
        public static let favoriteButton = "property_details_favorite_button"
        public static let shareButton = "property_details_share_button"
        public static let closeButton = "property_details_close_button"
        public static let propertyName = "property_details_name"
        public static let propertyRating = "property_details_rating"
        public static let propertyAddress = "property_details_address"
        public static let amenitiesList = "property_details_amenities_list"
        public static let roomTypesList = "property_details_room_types_list"
        public static let reviewsSection = "property_details_reviews_section"
        public static let policiesSection = "property_details_policies_section"
        public static let locationSection = "property_details_location_section"
        
        public static func roomTypeCard(_ roomTypeId: String) -> String {
            "property_details_room_type_\(roomTypeId)"
        }
        
        public static func roomSelectButton(_ roomTypeId: String) -> String {
            "property_details_room_select_\(roomTypeId)"
        }
    }
    
    // MARK: - Booking Screen
    public enum Booking {
        public static let progressIndicator = "booking_progress_indicator"
        public static let bookingSummary = "booking_summary"
        public static let guestDetailsSection = "booking_guest_details"
        public static let paymentDetailsSection = "booking_payment_details"
        public static let confirmationSection = "booking_confirmation"
        public static let previousButton = "booking_previous_button"
        public static let continueButton = "booking_continue_button"
        public static let completeBookingButton = "booking_complete_button"
        public static let cancelButton = "booking_cancel_button"
        public static let termsToggle = "booking_terms_toggle"
        public static let updatesToggle = "booking_updates_toggle"
        public static let paymentMethodButton = "booking_payment_method_button"
        public static let specialRequestsField = "booking_special_requests_field"
        
        public static func guestForm(_ guestIndex: Int) -> String {
            "booking_guest_form_\(guestIndex)"
        }
        
        public static func guestNameField(_ guestIndex: Int, _ field: String) -> String {
            "booking_guest_\(guestIndex)_\(field)_field"
        }
    }
    
    // MARK: - Saved Properties Screen
    public enum SavedProperties {
        public static let tabBar = "saved_properties_tab_bar"
        public static let favoritesTab = "saved_properties_favorites_tab"
        public static let shortlistsTab = "saved_properties_shortlists_tab"
        public static let recentTab = "saved_properties_recent_tab"
        public static let filterButton = "saved_properties_filter_button"
        public static let closeButton = "saved_properties_close_button"
        public static let emptyStateView = "saved_properties_empty_state"
        public static let createShortlistButton = "saved_properties_create_shortlist_button"
        public static let clearRecentButton = "saved_properties_clear_recent_button"
        
        public static func savedPropertyCard(_ propertyId: String) -> String {
            "saved_property_card_\(propertyId)"
        }
        
        public static func shortlistCard(_ shortlistId: String) -> String {
            "shortlist_card_\(shortlistId)"
        }
        
        public static func removeFromFavoritesButton(_ propertyId: String) -> String {
            "remove_from_favorites_\(propertyId)"
        }
    }
    
    // MARK: - Import Booking Screen
    public enum ImportBooking {
        public static let headerSection = "import_booking_header"
        public static let methodSelector = "import_booking_method_selector"
        public static let urlMethodCard = "import_booking_url_method"
        public static let confirmationMethodCard = "import_booking_confirmation_method"
        public static let urlTextField = "import_booking_url_field"
        public static let pasteButton = "import_booking_paste_button"
        public static let providerPicker = "import_booking_provider_picker"
        public static let confirmationCodeField = "import_booking_confirmation_code_field"
        public static let lastNameField = "import_booking_last_name_field"
        public static let importButton = "import_booking_import_button"
        public static let supportedProvidersSection = "import_booking_supported_providers"
        public static let doneButton = "import_booking_done_button"
    }
    
    // MARK: - Photo Gallery Screen
    public enum PhotoGallery {
        public static let photoTabView = "photo_gallery_tab_view"
        public static let closeButton = "photo_gallery_close_button"
        public static let shareButton = "photo_gallery_share_button"
        public static let photoCounter = "photo_gallery_counter"
        public static let photoCaption = "photo_gallery_caption"
        
        public static func zoomableImage(_ index: Int) -> String {
            "photo_gallery_image_\(index)"
        }
    }
    
    // MARK: - Voice Input Screen
    public enum VoiceInput {
        public static let microphoneButton = "voice_input_microphone_button"
        public static let statusLabel = "voice_input_status_label"
        public static let transcriptionText = "voice_input_transcription_text"
        public static let stopButton = "voice_input_stop_button"
        public static let clearButton = "voice_input_clear_button"
        public static let searchButton = "voice_input_search_button"
    }
    
    // MARK: - Common UI Elements
    public enum Common {
        public static let navigationTitle = "navigation_title"
        public static let backButton = "back_button"
        public static let dismissButton = "dismiss_button"
        public static let loadingIndicator = "loading_indicator"
        public static let errorMessage = "error_message"
        public static let retryButton = "retry_button"
        public static let refreshButton = "refresh_button"
    }
}