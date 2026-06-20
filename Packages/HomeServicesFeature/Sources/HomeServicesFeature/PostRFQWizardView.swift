import SwiftUI
import HomeServicesService
import PhotosUI
import CoreLocation
import FirebaseStorage
import FirebaseAuth

public struct PostRFQWizardView: View {
    @ObservedObject var viewModel: HomeServicesViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Wizard state
    @State private var currentStep = 1
    @State private var selectedCategory: ServiceCategory?
    @State private var title = ""
    @State private var description = ""
    @State private var urgency: RFQ.RFQScope.Urgency = .flexible
    @State private var budgetMin = ""
    @State private var budgetMax = ""
    @State private var location = RFQ.Location(lat: 33.5731, lng: -7.5898, city: "Casablanca")
    @State private var siteVisitRequested = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var uploadedMediaUrls: [String] = []
    @State private var isUploadingPhotos = false
    @State private var uploadProgress: Double = 0
    
    let preselectedCategory: ServiceCategory?
    
    public init(viewModel: HomeServicesViewModel, preselectedCategory: ServiceCategory? = nil) {
        self.viewModel = viewModel
        self.preselectedCategory = preselectedCategory
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentStep), total: 4)
                    .padding()
                
                // Content based on step
                Group {
                    switch currentStep {
                    case 1:
                        CategorySelectionStep(
                            categories: viewModel.categories,
                            selectedCategory: $selectedCategory
                        )
                    case 2:
                        DetailsStep(
                            title: $title,
                            description: $description,
                            urgency: $urgency,
                            selectedPhotos: $selectedPhotos
                        )
                    case 3:
                        BudgetLocationStep(
                            budgetMin: $budgetMin,
                            budgetMax: $budgetMax,
                            location: $location,
                            siteVisitRequested: $siteVisitRequested
                        )
                    case 4:
                        ReviewStep(
                            category: selectedCategory,
                            title: title,
                            description: description,
                            urgency: urgency,
                            budget: budgetMin.isEmpty ? nil : RFQ.BudgetRange(
                                min: Double(budgetMin) ?? 0,
                                max: Double(budgetMax) ?? 0
                            ),
                            location: location,
                            siteVisitRequested: siteVisitRequested,
                            photosCount: selectedPhotos.count,
                            isUploadingPhotos: isUploadingPhotos,
                            uploadProgress: uploadProgress
                        )
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 1 {
                        Button("Previous") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if currentStep < 4 {
                        Button("Next") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isStepValid(currentStep))
                    } else {
                        Button(action: {
                            Task {
                                await submitRFQ()
                            }
                        }) {
                            if viewModel.isLoading || isUploadingPhotos {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Text("Post Request")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isLoading || isUploadingPhotos)
                    }
                }
                .padding()
            }
            .navigationTitle("Post Service Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let preselected = preselectedCategory {
                    selectedCategory = preselected
                    currentStep = 2
                }
            }
        }
    }
    
    private func isStepValid(_ step: Int) -> Bool {
        switch step {
        case 1:
            return selectedCategory != nil
        case 2:
            return !title.isEmpty && !description.isEmpty
        case 3:
            return true // Budget is optional
        default:
            return true
        }
    }
    
    private func submitRFQ() async {
        // Upload photos first if any selected
        if !selectedPhotos.isEmpty {
            isUploadingPhotos = true
            uploadedMediaUrls = await uploadPhotos()
            isUploadingPhotos = false
        }
        
        let draft = RFQDraft(
            categoryId: selectedCategory?.id ?? "",
            scope: RFQ.RFQScope(
                title: title,
                description: description,
                urgency: urgency
            ),
            location: location,
            budgetRange: budgetMin.isEmpty ? nil : RFQ.BudgetRange(
                min: Double(budgetMin) ?? 0,
                max: Double(budgetMax) ?? 0
            ),
            siteVisitRequested: siteVisitRequested,
            media: uploadedMediaUrls
        )
        
        if let _ = await viewModel.createRFQ(draft) {
            dismiss()
        }
    }
    
    private func uploadPhotos() async -> [String] {
        var urls: [String] = []
        let storage = Storage.storage()
        let userId = Auth.auth().currentUser?.uid ?? "anonymous"
        
        for (index, item) in selectedPhotos.enumerated() {
            do {
                // Load image data
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                
                // Create storage reference
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileName = "rfq_\(userId)_\(timestamp)_\(index).jpg"
                let storageRef = storage.reference().child("home-services/rfq-photos/\(fileName)")
                
                // Upload with progress tracking
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                // Compress image if needed
                let compressedData = await compressImageData(data)
                
                // Upload
                _ = try await storageRef.putDataAsync(compressedData, metadata: metadata)
                
                // Get download URL
                let url = try await storageRef.downloadURL()
                urls.append(url.absoluteString)
                
                // Update progress
                uploadProgress = Double(index + 1) / Double(selectedPhotos.count)
            } catch {
                print("Failed to upload photo \(index): \(error)")
            }
        }
        
        return urls
    }
    
    private func compressImageData(_ data: Data) async -> Data {
        #if os(iOS)
        guard let image = UIImage(data: data) else { return data }
        
        // Compress to reduce size (80% quality)
        let compressedData = image.jpegData(compressionQuality: 0.8) ?? data
        
        // If still too large, reduce further
        if compressedData.count > 2_000_000 { // 2MB limit
            return image.jpegData(compressionQuality: 0.5) ?? data
        }
        
        return compressedData
        #else
        return data
        #endif
    }
}

// MARK: - Step 1: Category Selection
struct CategorySelectionStep: View {
    let categories: [ServiceCategory]
    @Binding var selectedCategory: ServiceCategory?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("What service do you need?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(categories) { category in
                        CategorySelectionCard(
                            category: category,
                            isSelected: selectedCategory?.id == category.id
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

struct CategorySelectionCard: View {
    let category: ServiceCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Step 2: Details
struct DetailsStep: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var urgency: RFQ.RFQScope.Urgency
    @Binding var selectedPhotos: [PhotosPickerItem]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Describe your needs")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("e.g., Paint 2-bedroom apartment", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("When do you need this?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Urgency", selection: $urgency) {
                        Text("ASAP").tag(RFQ.RFQScope.Urgency.asap)
                        Text("Flexible").tag(RFQ.RFQScope.Urgency.flexible)
                        Text("Scheduled").tag(RFQ.RFQScope.Urgency.scheduled)
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Photos (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    PhotosPicker(selection: $selectedPhotos,
                                maxSelectionCount: 5,
                                matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                            if selectedPhotos.isEmpty {
                                Text("Select photos")
                            } else {
                                Text("\(selectedPhotos.count) photo(s) selected")
                                    .fontWeight(.medium)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    
                    if !selectedPhotos.isEmpty {
                        Text("Photos will be uploaded when you submit the request")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Step 3: Budget & Location
struct BudgetLocationStep: View {
    @Binding var budgetMin: String
    @Binding var budgetMax: String
    @Binding var location: RFQ.Location
    @Binding var siteVisitRequested: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Budget & Location")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Budget Range (MAD) - Optional")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        TextField("Min", text: $budgetMin)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("to")
                            .foregroundColor(.secondary)
                        
                        TextField("Max", text: $budgetMax)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Service Location")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Simplified location selector for MVP
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text(location.city)
                                .font(.body)
                        }
                        
                        TextField("Address (Optional)", text: .init(
                            get: { location.address ?? "" },
                            set: { location.address = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                Toggle(isOn: $siteVisitRequested) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Request Site Visit")
                            .font(.body)
                        Text("Pro will visit to assess before quoting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            .padding()
        }
    }
}

// MARK: - Step 4: Review
struct ReviewStep: View {
    let category: ServiceCategory?
    let title: String
    let description: String
    let urgency: RFQ.RFQScope.Urgency
    let budget: RFQ.BudgetRange?
    let location: RFQ.Location
    let siteVisitRequested: Bool
    let photosCount: Int
    let isUploadingPhotos: Bool
    let uploadProgress: Double
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Review Your Request")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    ReviewItem(label: "Category", value: category?.name ?? "")
                    ReviewItem(label: "Title", value: title)
                    ReviewItem(label: "Description", value: description)
                    ReviewItem(label: "Urgency", value: urgency.rawValue.capitalized)
                    
                    if let budget = budget {
                        ReviewItem(label: "Budget", value: "\(Int(budget.min))-\(Int(budget.max)) MAD")
                    }
                    
                    ReviewItem(label: "Location", value: "\(location.city) \(location.address ?? "")")
                    
                    if siteVisitRequested {
                        ReviewItem(label: "Site Visit", value: "Requested")
                    }
                    
                    if photosCount > 0 {
                        ReviewItem(label: "Photos", value: "\(photosCount) attached")
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                if isUploadingPhotos {
                    VStack(spacing: 8) {
                        ProgressView(value: uploadProgress) {
                            Text("Uploading photos...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("\(Int(uploadProgress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                Text("Your request will be sent to qualified professionals in your area.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

struct ReviewItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}