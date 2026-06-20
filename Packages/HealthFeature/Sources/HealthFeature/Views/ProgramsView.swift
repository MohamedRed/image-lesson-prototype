import SwiftUI
import HealthService

struct ProgramsView: View {
    @EnvironmentObject private var healthViewModel: HealthViewModel
    @StateObject private var programsViewModel = ProgramsViewModel(healthService: HealthService.shared)
    @State private var showingCreateProgram = false
    @State private var selectedProgram: HealthProgram?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if programsViewModel.programs.isEmpty && !programsViewModel.isLoading {
                        emptyStateView
                    } else {
                        activeProgramsSection
                        availableProgramsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Programs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create Program") {
                        showingCreateProgram = true
                    }
                }
            }
            .refreshable {
                await programsViewModel.loadPrograms()
            }
            .sheet(isPresented: $showingCreateProgram) {
                CreateProgramView()
                    .environmentObject(programsViewModel)
            }
            .sheet(item: $selectedProgram) { program in
                ProgramDetailView(program: program)
                    .environmentObject(programsViewModel)
            }
        }
        .task {
            await programsViewModel.loadPrograms()
        }
        .overlay {
            if programsViewModel.isLoading {
                ProgressView("Loading programs...")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Programs Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first health program to start your wellness journey")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Get Started") {
                showingCreateProgram = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.top, 80)
    }
    
    private var activeProgramsSection: some View {
        Group {
            let activePrograms = programsViewModel.programs.filter { $0.status == .active }
            if !activePrograms.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Programs")
                        .font(.headline)
                    
                    ForEach(activePrograms, id: \.id) { program in
                        ProgramCard(program: program, isCompact: false) {
                            selectedProgram = program
                        }
                    }
                }
            }
        }
    }
    
    private var availableProgramsSection: some View {
        Group {
            let otherPrograms = programsViewModel.programs.filter { $0.status != .active }
            if !otherPrograms.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("All Programs")
                        .font(.headline)
                    
                    ForEach(otherPrograms, id: \.id) { program in
                        ProgramCard(program: program, isCompact: true) {
                            selectedProgram = program
                        }
                    }
                }
            }
        }
    }
}

struct ProgramCard: View {
    let program: HealthProgram
    let isCompact: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(program.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(isCompact ? 2 : 3)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        statusBadge
                        
                        if !isCompact {
                            Text("\(program.progress.completedSteps)/\(program.progress.totalSteps) steps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !isCompact && program.status == .active {
                    progressSection
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusBadge: some View {
        Text(program.status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
    
    private var statusColor: Color {
        switch program.status {
        case .active: return .green
        case .paused: return .orange
        case .completed: return .blue
        case .draft: return .gray
        case .abandoned: return .gray
        }
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(progressFraction * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: progressFraction)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
        }
    }

    private var progressFraction: Double {
        let total = max(program.progress.totalSteps, 1)
        return Double(program.progress.completedSteps) / Double(total)
    }
}

struct CreateProgramView: View {
    @EnvironmentObject private var programsViewModel: ProgramsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGoal: HealthGoal?
    @State private var goalTitle = ""
    @State private var goalDescription = ""
    @State private var goalType: HealthGoal.GoalType = .weightLoss
    @State private var targetValue: Double = 0
    @State private var targetDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Information") {
                    TextField("Goal Title", text: $goalTitle)
                    
                    TextField("Description", text: $goalDescription, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Goal Type", selection: $goalType) {
                        ForEach(HealthGoal.GoalType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                }
                
                Section("Target") {
                    HStack {
                        Text("Target Value")
                        Spacer()
                        TextField("Value", value: $targetValue, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Create Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createProgram()
                    }
                    .disabled(goalTitle.isEmpty)
                }
            }
        }
    }
    
    private func createProgram() {
        let comparison: HealthGoal.TargetValue.ComparisonType
        switch goalType {
        case .weightLoss: comparison = .lessThan
        case .weightGain, .muscleGain, .strength, .endurance, .flexibility, .nutrition, .sleep: comparison = .greaterThan
        case .stress, .custom: comparison = .equalTo
        }

        let target = HealthGoal.TargetValue(
            value: targetValue,
            unit: goalType.defaultUnit,
            comparisonType: comparison
        )

        let goal = HealthGoal(
            type: goalType,
            title: goalTitle,
            description: goalDescription,
            target: target,
            currentValue: 0,
            startDate: Date(),
            endDate: targetDate,
            status: .active
        )
        
        Task {
            await programsViewModel.createProgram(for: goal)
            dismiss()
        }
    }
}

struct ProgramDetailView: View {
    let program: HealthProgram
    @EnvironmentObject private var programsViewModel: ProgramsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    programHeaderSection
                    progressSection
                    stepsSection
                    outcomesSection
                }
                .padding()
            }
            .navigationTitle(program.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if program.status == .active {
                            Button("Pause Program") {
                                Task {
                                    await programsViewModel.pauseProgram(program.id)
                                }
                            }
                        } else if program.status == .paused {
                            Button("Resume Program") {
                                Task {
                                    await programsViewModel.resumeProgram(program.id)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private var programHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(program.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        statusBadge
                        Spacer()
                        Text("Created \(program.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var statusBadge: some View {
        Text(program.status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
    
    private var statusColor: Color {
        switch program.status {
        case .active: return .green
        case .paused: return .orange
        case .completed: return .blue
        case .draft: return .gray
        case .abandoned: return .gray
        }
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(program.progress.completedSteps) of \(program.progress.totalSteps) steps completed")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(Int(progressFraction * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: progressFraction)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var progressFraction: Double {
        let total = max(program.progress.totalSteps, 1)
        return Double(program.progress.completedSteps) / Double(total)
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Tasks")
                .font(.headline)
            
            ForEach(program.steps.prefix(5), id: \.id) { step in
                ProgramStepDetailRow(step: step) { stepId in
                    Task {
                        await programsViewModel.updateProgress(
                            programId: program.id,
                            stepId: stepId,
                            completed: !step.isCompleted
                        )
                    }
                }
            }
        }
    }
    
    private var outcomesSection: some View {
        Group {
            if !program.outcomes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Expected Outcomes")
                        .font(.headline)
                    
                    ForEach(Array(program.outcomes.enumerated()), id: \.offset) { _, outcome in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(outcome.metric): \(outcome.expectedChange) \(outcome.unit)")
                                    .font(.subheadline)
                                
                                Text("Timeline: \(outcome.timeframe)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(Int(outcome.confidence * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
}

struct ProgramStepDetailRow: View {
    let step: ProgramStep
    let onComplete: (String) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                onComplete(step.id)
            } label: {
                Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(step.isCompleted ? .green : .gray)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(step.isCompleted)
                
                Text(step.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if let duration = step.duration {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(Int(duration / 60)) min")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if step.isCompleted {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

extension HealthGoal.GoalType {
    var defaultUnit: String {
        switch self {
        case .weightLoss, .weightGain, .muscleGain: return "kg"
        case .endurance: return "minutes"
        case .strength: return "reps"
        case .flexibility: return "minutes"
        case .nutrition: return "kcal"
        case .sleep: return "hours"
        case .stress: return "score"
        case .custom: return "units"
        }
    }
}

#Preview {
    NavigationStack {
        ProgramsView()
    }
}