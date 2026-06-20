import SwiftUI
import FoodDeliveryService

/// Main merchant console interface for restaurant management
public struct MerchantConsoleView: View {
    @StateObject private var viewModel: MerchantConsoleViewModel
    @State private var selectedTab: MerchantTab = .dashboard
    @Environment(\.dismiss) private var dismiss
    
    public init(restaurantId: String, service: FoodDeliveryServicing) {
        self._viewModel = StateObject(wrappedValue: MerchantConsoleViewModel(restaurantId: restaurantId, service: service))
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Restaurant header
                RestaurantHeaderView(restaurant: viewModel.restaurant)
                
                // Tab navigation
                MerchantTabBar(selectedTab: $selectedTab)
                
                // Tab content
                TabView(selection: $selectedTab) {
                    MerchantDashboardView(viewModel: viewModel)
                        .tag(MerchantTab.dashboard)
                    
                    OrderManagementView(viewModel: viewModel)
                        .tag(MerchantTab.orders)
                    
                    MenuManagementView(viewModel: viewModel)
                        .tag(MerchantTab.menu)
                    
                    MerchantAnalyticsView(viewModel: viewModel)
                        .tag(MerchantTab.analytics)
                    
                    RestaurantSettingsView(viewModel: viewModel)
                        .tag(MerchantTab.settings)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Merchant Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // Online/Offline toggle
                        OnlineToggleButton(viewModel: viewModel)
                        
                        // Notifications
                        NotificationsBadge(count: viewModel.unreadNotifications)
                    }
                }
            }
        }
        .task {
            await viewModel.initialize()
        }
    }
}

// MARK: - Merchant Tab Enum
enum MerchantTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case orders = "Orders"
    case menu = "Menu"
    case analytics = "Analytics"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .orders: return "list.bullet.clipboard"
        case .menu: return "menucard"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Restaurant Header View
struct RestaurantHeaderView: View {
    let restaurant: Restaurant?
    
    var body: some View {
        HStack(spacing: 12) {
            // Restaurant logo
            AsyncImage(url: restaurant?.logoUrl.flatMap(URL.init)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "building.2")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant?.name ?? "Loading...")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 16) {
                    Label(String(format: "%.1f", restaurant?.rating ?? 0.0), systemImage: "star.fill")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Text(restaurant?.isOpen == true ? "Open" : "Closed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(restaurant?.isOpen == true ? .green : .red)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Merchant Tab Bar
struct MerchantTabBar: View {
    @Binding var selectedTab: MerchantTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MerchantTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// MARK: - Online Toggle Button
struct OnlineToggleButton: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    
    var body: some View {
        Button(action: {
            Task {
                await viewModel.toggleRestaurantStatus()
            }
        }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.restaurant?.isOpen == true ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.restaurant?.isOpen == true ? "Online" : "Offline")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Notifications Badge
struct NotificationsBadge: View {
    let count: Int
    
    var body: some View {
        Button(action: {
            // Handle notifications tap
        }) {
            ZStack {
                Image(systemName: "bell")
                    .font(.title3)
                    .foregroundColor(.primary)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
    }
}

// MARK: - Merchant Dashboard View
struct MerchantDashboardView: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Quick stats
                DashboardStatsSection(viewModel: viewModel)
                
                // Recent orders
                RecentOrdersSection(viewModel: viewModel)
                
                // Today's performance
                TodaysPerformanceSection(viewModel: viewModel)
                
                // Quick actions
                QuickActionsSection(viewModel: viewModel)
            }
            .padding()
        }
        .refreshable {
            await viewModel.refreshDashboard()
        }
    }
}

// MARK: - Dashboard Stats Section
struct DashboardStatsSection: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                DashboardStatCard(
                    title: "Orders",
                    value: "\(viewModel.todaysStats.totalOrders)",
                    subtitle: "+\(viewModel.todaysStats.newOrders) new",
                    icon: "bag.fill",
                    color: .blue
                )
                
                DashboardStatCard(
                    title: "Revenue",
                    value: String(format: "%.0f MAD", viewModel.todaysStats.revenue),
                    subtitle: (viewModel.todaysStats.revenueGrowth > 0 ? "+" : "") + String(format: "%.1f%%", viewModel.todaysStats.revenueGrowth),
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                DashboardStatCard(
                    title: "Avg Prep Time",
                    value: "\(viewModel.todaysStats.avgPrepTime) min",
                    subtitle: viewModel.todaysStats.prepTimeChange > 0 ? "↑ Slower" : "↓ Faster",
                    icon: "clock.fill",
                    color: .orange
                )
                
                DashboardStatCard(
                    title: "Rating",
                    value: String(format: "%.1f", viewModel.todaysStats.avgRating),
                    subtitle: "\(viewModel.todaysStats.totalReviews) reviews",
                    icon: "star.fill",
                    color: .yellow
                )
            }
        }
    }
}

// MARK: - Dashboard Stat Card
struct DashboardStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Recent Orders Section
struct RecentOrdersSection: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Orders")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    // Switch to orders tab
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                ForEach(viewModel.recentOrders.prefix(5), id: \.id) { order in
                    RecentOrderRow(order: order) {
                        Task {
                            if let id = order.id { await viewModel.handleOrderAction(id, action: .viewDetails) }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Recent Order Row
struct RecentOrderRow: View {
    let order: Order
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Order status indicator
                Circle()
                    .fill(order.status.merchantColor)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Order #\((order.id ?? "").suffix(6))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(order.items.count) items • " + String(format: "%.0f MAD", order.total))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(order.status.merchantDisplayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(order.status.merchantColor)
                    
                    if let createdAt = order.timings.createdAt {
                        Text(createdAt, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Today's Performance Section
struct TodaysPerformanceSection: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                PerformanceMetricRow(
                    title: "Order Acceptance Rate",
                    value: String(format: "%.1f%%", viewModel.todaysStats.acceptanceRate),
                    progress: viewModel.todaysStats.acceptanceRate / 100,
                    color: .green
                )
                
                PerformanceMetricRow(
                    title: "Average Prep Time",
                    value: "\(viewModel.todaysStats.avgPrepTime) min",
                    progress: max(0, min(1, 1 - (Double(viewModel.todaysStats.avgPrepTime) - 15) / 30)),
                    color: .blue
                )
                
                PerformanceMetricRow(
                    title: "Customer Satisfaction",
                    value: String(format: "%.1f ★", viewModel.todaysStats.avgRating),
                    progress: viewModel.todaysStats.avgRating / 5.0,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Performance Metric Row
struct PerformanceMetricRow: View {
    let title: String
    let value: String
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
        }
    }
}

// MARK: - Quick Actions Section
struct QuickActionsSection: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Pause Orders",
                    subtitle: "Temporarily stop orders",
                    icon: "pause.circle",
                    color: .orange
                ) {
                    Task { await viewModel.pauseRestaurant(minutes: 30) }
                }
                
                QuickActionButton(
                    title: "Update Menu",
                    subtitle: "Modify items & prices",
                    icon: "pencil.circle",
                    color: .blue
                ) {
                    // Navigate to menu management
                }
                
                QuickActionButton(
                    title: "View Analytics",
                    subtitle: "Sales & performance",
                    icon: "chart.bar.xaxis",
                    color: .green
                ) {
                    // Navigate to analytics
                }
                
                QuickActionButton(
                    title: "Contact Support",
                    subtitle: "Get help & assistance",
                    icon: "questionmark.circle",
                    color: .purple
                ) {
                    // Open support
                }
            }
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Extensions
extension Order.OrderStatus {
    var merchantColor: Color {
        switch self {
        case .created: return .blue
        case .restaurantAccepted: return .green
        case .preparing: return .orange
        case .readyForPickup: return .purple
        case .pickedUp: return .blue
        case .onRoute: return .blue
        case .delivered: return .green
        case .cancelledByCustomer, .cancelledByMerchant, .cancelledNoCourier: return .red
        }
    }
    
    var merchantDisplayName: String {
        switch self {
        case .created: return "New"
        case .restaurantAccepted: return "Accepted"
        case .preparing: return "Preparing"
        case .readyForPickup: return "Ready"
        case .pickedUp: return "Picked Up"
        case .onRoute: return "On Route"
        case .delivered: return "Delivered"
        case .cancelledByCustomer: return "Cancelled"
        case .cancelledByMerchant: return "Cancelled"
        case .cancelledNoCourier: return "Cancelled"
        }
    }
}

#Preview {
    MerchantConsoleView(
        restaurantId: "rest1",
        service: MockFoodDeliveryService()
    )
}