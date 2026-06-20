import SwiftUI
import MarketplaceService
import PhotosUI

/// AI-powered listing creation flow
/// Per Section 10 of implementation-plan.md - Fast listing creation with AI
public struct CreateListingFlow: View {
    @ObservedObject var viewModel: MarketplaceViewModel
    let cityId: String
    
    @State private var currentStep = 0
    @State private var photos: [UIImage] = []
    @State private var title = ""
    @State private var description = ""
    @State private var category: ListingCategory = .other
    @State private var condition: ItemCondition = .good
    @State private var price = ""
    @State private var currency = "MAD"
    @State private var neighborhood = ""
    @State private var addressLine = ""
    @State private var enableMeetup = true
    @State private var enableCourier = false
    @State private var attributes: [String: String] = [:]
    
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var isProcessing = false
    @State private var priceSuggestion: PricingSuggestion?
    
    @Environment(\.dismiss) private var dismiss
    
    private let steps = ["Photos", "Details", "Price", "Location", "Review"]
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress bar
                ProgressBar(currentStep: currentStep, totalSteps: steps.count, stepTitles: steps)
                    .padding()
                
                // Content
                Group {
                    switch currentStep {
                    case 0:
                        PhotosStep(
                            photos: $photos,
                            showingPhotoPicker: $showingPhotoPicker,
                            showingCamera: $showingCamera
                        )
                    case 1:
                        DetailsStep(
                            title: $title,
                            description: $description,
                            category: $category,
                            condition: $condition,
                            photos: photos,
                            isProcessing: $isProcessing
                        )
                    case 2:
                        PriceStep(
                            price: $price,
                            currency: $currency,
                            category: category,
                            condition: condition,
                            title: title,
                            cityId: cityId,
                            priceSuggestion: $priceSuggestion,
                            viewModel: viewModel
                        )
                    case 3:
                        LocationStep(
                            cityId: cityId,
                            neighborhood: $neighborhood,
                            addressLine: $addressLine,
                            enableMeetup: $enableMeetup,
                            enableCourier: $enableCourier
                        )
                    case 4:
                        ReviewStep(
                            photos: photos,
                            title: title,
                            description: description,
                            category: category,
                            condition: condition,
                            price: price,
                            currency: currency,
                            neighborhood: neighborhood,
                            enableMeetup: enableMeetup,
                            enableCourier: enableCourier
                        )
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Previous") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if currentStep < steps.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canProceed)
                    } else {
                        Button("Publish") {
                            publishListing()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isProcessing)
                    }
                }
                .padding()
            }
            .navigationTitle("Create Listing")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Group {
                    if isProcessing {
                        ProgressView()
                    }
                }
            )
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoPicker(images: $photos)
        }
        .sheet(isPresented: $showingCamera) {
            ListingCameraView(photos: $photos)
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return !photos.isEmpty
        case 1: return !title.isEmpty && !description.isEmpty
        case 2: return !price.isEmpty
        case 3: return !neighborhood.isEmpty
        default: return true
        }
    }
    
    private func publishListing() {
        isProcessing = true
        
        Task {
            do {
                let coords = getNeighborhoodCoordinates(neighborhood)
                let location = Listing.Location(
                    lat: coords.latitude,
                    lng: coords.longitude,
                    addressLine: addressLine.isEmpty ? nil : addressLine,
                    arrondissement: neighborhood
                )
                
                let draft = ListingDraft(
                    title: title,
                    description: description,
                    category: category,
                    condition: condition,
                    price: Money(
                        amount: Int(Double(price) ?? 0) * 100,
                        currency: currency
                    ),
                    images: photos.compactMap { $0.jpegData(compressionQuality: 0.8) },
                    location: location,
                    deliveryOptions: Listing.DeliveryOptions(
                        meetup: enableMeetup,
                        courier: enableCourier
                    ),
                    attributes: attributes
                )
                
                _ = try await viewModel.createListing(draft)
                dismiss()
            } catch {
                // Handle error
                isProcessing = false
            }
        }
    }
    
    private func getNeighborhoodCoordinates(_ neighborhood: String) -> Coordinates {
        // Simplified - would use actual coordinates
        return Coordinates(latitude: 33.5731, longitude: -7.5898)
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    let stepTitles: [String]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Rectangle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                }
            }
            
            Text(stepTitles[min(currentStep, stepTitles.count - 1)])
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Photos Step

struct PhotosStep: View {
    @Binding var photos: [UIImage]
    @Binding var showingPhotoPicker: Bool
    @Binding var showingCamera: Bool
    
    private let maxPhotos = 10
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add Photos")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Add up to \(maxPhotos) photos. The first photo will be your main image.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        PhotoThumbnail(
                            image: photo,
                            isMain: index == 0,
                            onDelete: {
                                photos.remove(at: index)
                            }
                        )
                    }
                    
                    if photos.count < maxPhotos {
                        AddPhotoButton(
                            showingPhotoPicker: $showingPhotoPicker,
                            showingCamera: $showingCamera
                        )
                    }
                }
                .padding()
            }
            
            if !photos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI will enhance your photos", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundColor(.purple)
                    
                    Text("• Auto background cleanup\n• Brightness optimization\n• Smart cropping")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct PhotoThumbnail: View {
    let image: UIImage
    let isMain: Bool
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipped()
                .cornerRadius(8)
                .overlay(
                    isMain ? 
                    Text("Main")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(4)
                    : nil,
                    alignment: .bottomLeading
                )
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(4)
        }
    }
}

struct AddPhotoButton: View {
    @Binding var showingPhotoPicker: Bool
    @Binding var showingCamera: Bool
    
    var body: some View {
        Menu {
            Button(action: { showingPhotoPicker = true }) {
                Label("Choose from Library", systemImage: "photo")
            }
            Button(action: { showingCamera = true }) {
                Label("Take Photo", systemImage: "camera")
            }
        } label: {
            VStack {
                Image(systemName: "plus")
                    .font(.title2)
                Text("Add Photo")
                    .font(.caption)
            }
            .foregroundColor(.blue)
            .frame(width: 100, height: 100)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Details Step

struct DetailsStep: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var category: ListingCategory
    @Binding var condition: ItemCondition
    let photos: [UIImage]
    @Binding var isProcessing: Bool
    
    @State private var showingAISuggestions = false
    @State private var aiSuggestions: AISuggestions?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Item Details")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // AI suggestion button
                if !photos.isEmpty {
                    Button(action: generateAISuggestions) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate with AI")
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
                }
                
                // Title
                VStack(alignment: .leading) {
                    Text("Title")
                        .font(.headline)
                    TextField("What are you selling?", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Category
                VStack(alignment: .leading) {
                    Text("Category")
                        .font(.headline)
                    Picker("Category", selection: $category) {
                        ForEach(ListingCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Condition
                VStack(alignment: .leading) {
                    Text("Condition")
                        .font(.headline)
                    Picker("Condition", selection: $condition) {
                        ForEach(ItemCondition.allCases, id: \.self) { cond in
                            Text(cond.displayName).tag(cond)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Description
                VStack(alignment: .leading) {
                    Text("Description")
                        .font(.headline)
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .padding(4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingAISuggestions) {
            if let suggestions = aiSuggestions {
                AISuggestionsView(
                    suggestions: suggestions,
                    onApply: { appliedSuggestions in
                        title = appliedSuggestions.title
                        description = appliedSuggestions.description
                        category = appliedSuggestions.category
                        showingAISuggestions = false
                    }
                )
            }
        }
    }
    
    private func generateAISuggestions() {
        isProcessing = true
        
        // Simulate AI processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            aiSuggestions = AISuggestions(
                title: "Professional DSLR Camera - Canon EOS 5D Mark IV",
                description: "Excellent condition Canon 5D Mark IV with original box and accessories. Perfect for professional photography or serious hobbyists. Shutter count: 15,000. Includes battery grip, 2 batteries, charger, and camera strap.",
                category: .electronics,
                tags: ["camera", "photography", "canon", "dslr"]
            )
            isProcessing = false
            showingAISuggestions = true
        }
    }
}

struct AISuggestions {
    let title: String
    let description: String
    let category: ListingCategory
    let tags: [String]
}

struct AISuggestionsView: View {
    let suggestions: AISuggestions
    let onApply: (AISuggestions) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("AI Suggestions")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("Title", systemImage: "textformat")
                        .font(.headline)
                    Text(suggestions.title)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("Category", systemImage: "square.grid.2x2")
                        .font(.headline)
                    Text(suggestions.category.displayName)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("Description", systemImage: "text.alignleft")
                        .font(.headline)
                    Text(suggestions.description)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: { onApply(suggestions) }) {
                    Text("Apply Suggestions")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

// Placeholder views for photo picker and camera
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 10
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let image = image as? UIImage {
                            DispatchQueue.main.async {
                                self.parent.images.append(image)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ListingCameraView: View {
    @Binding var photos: [UIImage]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Text("Camera View - To Be Implemented")
            .onAppear {
                dismiss()
            }
    }
}