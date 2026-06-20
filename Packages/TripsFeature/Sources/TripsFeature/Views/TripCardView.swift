import SwiftUI
import TripsService

struct TripCardView: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Text(formatTripDuration())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                TripStatusBadge(status: trip.status)
            }
            
            // Budget and Members
            HStack {
                if let budget = trip.constraints.budget {
                    Label(budget.total.formatted, systemImage: "dollarsign.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if trip.members.count > 1 {
                    Label("\(trip.members.count) travelers", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress indicator
            if trip.status == .draft {
                ProgressView(value: calculateProgress())
                    .tint(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatTripDuration() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if let window = trip.startWindow {
            let startDate = window.start
            let endDate = window.end
            if Calendar.current.isDate(startDate, equalTo: endDate, toGranularity: .year) {
                formatter.dateFormat = "MMM d"
                let start = formatter.string(from: startDate)
                formatter.dateFormat = "MMM d, yyyy"
                let end = formatter.string(from: endDate)
                return "\(start) - \(end)"
            } else {
                formatter.dateStyle = .medium
                return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
            }
        } else {
            return "Flexible dates ( \(trip.duration.days) days)"
        }
    }
    
    private func calculateProgress() -> Double {
        switch trip.status {
        case .draft:
            return 0.3
        case .planned:
            return 0.8
        case .active:
            return 0.9
        case .completed:
            return 1.0
        case .booked, .cancelled:
            return 0.0
        }
    }
}

struct TripStatusBadge: View {
    let status: TripStatus
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private var statusText: String {
        switch status {
        case .draft: return "Draft"
        case .planned: return "Planned"
        case .booked: return "Booked"
        case .active: return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .draft: return .blue
        case .planned: return .green
        case .booked: return .orange
        case .active: return .purple
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

extension Money {
    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$\(amount)"
    }
}

#Preview {
    let sampleTrip = Trip(
        ownerId: "user1",
        title: "European Adventure",
        scope: .international,
        duration: TripDuration(days: 7, nights: 6),
        startWindow: DateInterval(start: Date(), duration: 7 * 24 * 60 * 60),
        constraints: TripConstraints(budget: BudgetConstraint(total: Money(amount: 5000.0))),
        status: .draft
    )
    
    return TripCardView(trip: sampleTrip)
        .padding()
        .previewLayout(.sizeThatFits)
}