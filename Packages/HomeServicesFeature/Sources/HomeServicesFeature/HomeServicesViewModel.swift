import Foundation
import Combine
import SwiftUI
import HomeServicesService

@MainActor
public class HomeServicesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var categories: [ServiceCategory] = []
    @Published var myRFQs: [RFQ] = []
    @Published var availableRFQs: [RFQ] = []
    @Published var myContracts: [Contract] = []
    @Published var proContracts: [Contract] = []
    @Published var currentRFQBids: [Bid] = []
    @Published var proProfile: ProProfile?
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Private Properties
    private let service: HomeServicesServicing
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init(service: HomeServicesServicing) {
        self.service = service
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Subscribe to real-time updates
        service.rfqUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rfq in
                self?.handleRFQUpdate(rfq)
            }
            .store(in: &cancellables)
        
        service.bidUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bid in
                self?.handleBidUpdate(bid)
            }
            .store(in: &cancellables)
        
        service.contractUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] contract in
                self?.handleContractUpdate(contract)
            }
            .store(in: &cancellables)
        
        service.messageUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.messages.append(message)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    public func loadCategories() async {
        do {
            isLoading = true
            categories = try await service.listCategories()
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    public func loadCustomerData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadCategories() }
            group.addTask { await self.loadMyRFQs() }
            group.addTask { await self.loadMyContracts(asPro: false) }
        }
    }
    
    public func loadProData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadCategories() }
            group.addTask { await self.loadAvailableRFQs() }
            group.addTask { await self.loadMyContracts(asPro: true) }
            group.addTask { await self.loadProProfile() }
        }
    }
    
    public func loadMyRFQs() async {
        do {
            isLoading = true
            myRFQs = try await service.listMyRFQs()
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    public func loadAvailableRFQs() async {
        do {
            isLoading = true
            // For now, using a mock pro ID - in real app, would get from auth
            availableRFQs = try await service.listAvailableRFQs(proId: "current-pro-id")
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    public func loadMyContracts(asPro: Bool) async {
        do {
            isLoading = true
            let contracts = try await service.listMyContracts(asPro: asPro)
            if asPro {
                proContracts = contracts
            } else {
                myContracts = contracts
            }
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    public func loadBids(for rfqId: String) async {
        do {
            isLoading = true
            currentRFQBids = try await service.listBids(rfqId: rfqId)
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    public func loadProProfile() async {
        do {
            // In real app, would get current user ID from auth
            proProfile = try await service.getProProfile(userId: "current-user-id")
        } catch {
            // Profile might not exist yet for new pros
            print("Pro profile not found")
        }
    }
    
    // MARK: - RFQ Actions
    
    public func createRFQ(_ draft: RFQDraft) async -> RFQ? {
        do {
            isLoading = true
            let rfq = try await service.createRFQ(draft)
            myRFQs.insert(rfq, at: 0)
            successMessage = "Request posted successfully!"
            isLoading = false
            return rfq
        } catch {
            handleError(error)
            return nil
        }
    }
    
    public func updateRFQ(id: String, draft: RFQDraft) async {
        do {
            isLoading = true
            let updated = try await service.updateRFQ(id: id, rfq: draft)
            if let index = myRFQs.firstIndex(where: { $0.id == id }) {
                myRFQs[index] = updated
            }
            successMessage = "Request updated successfully!"
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    public func cancelRFQ(id: String) async {
        do {
            isLoading = true
            try await service.cancelRFQ(id: id)
            if let index = myRFQs.firstIndex(where: { $0.id == id }) {
                myRFQs[index].status = .cancelled
            }
            successMessage = "Request cancelled"
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Bid Actions
    
    public func submitBid(_ bid: NewBid) async -> Bid? {
        do {
            isLoading = true
            let newBid = try await service.submitBid(bid)
            currentRFQBids.append(newBid)
            successMessage = "Bid submitted successfully!"
            isLoading = false
            return newBid
        } catch {
            handleError(error)
            return nil
        }
    }
    
    public func counterBid(_ counter: Counter) async {
        do {
            isLoading = true
            let updated = try await service.counterBid(counter)
            if let index = currentRFQBids.firstIndex(where: { $0.id == counter.bidId }) {
                currentRFQBids[index] = updated
            }
            successMessage = "Counter offer sent!"
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    public func withdrawBid(id: String) async {
        do {
            isLoading = true
            try await service.withdrawBid(id: id)
            currentRFQBids.removeAll { $0.id == id }
            successMessage = "Bid withdrawn"
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    public func acceptBid(_ bidId: String, depositPercent: Int? = nil) async -> Contract? {
        do {
            isLoading = true
            let contract = try await service.acceptBid(bidId, depositPercent: depositPercent)
            myContracts.insert(contract, at: 0)
            
            // Update RFQ status
            if let bid = currentRFQBids.first(where: { $0.id == bidId }),
               let rfqIndex = myRFQs.firstIndex(where: { $0.id == bid.rfqId }) {
                myRFQs[rfqIndex].status = .awarded
            }
            
            successMessage = "Bid accepted! Contract created."
            isLoading = false
            return contract
        } catch {
            handleError(error)
            return nil
        }
    }
    
    // MARK: - Contract Actions
    
    public func completeContract(_ contractId: String) async {
        do {
            isLoading = true
            try await service.completeContract(contractId)
            
            // Update local state
            if let index = myContracts.firstIndex(where: { $0.id == contractId }) {
                myContracts[index].status = .completed
            } else if let index = proContracts.firstIndex(where: { $0.id == contractId }) {
                proContracts[index].status = .completed
            }
            
            successMessage = "Contract completed successfully!"
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    public func cancelContract(_ contractId: String, reason: String) async {
        do {
            isLoading = true
            try await service.cancelContract(contractId, reason: reason)
            
            // Update local state
            if let index = myContracts.firstIndex(where: { $0.id == contractId }) {
                myContracts[index].status = .cancelled
            } else if let index = proContracts.firstIndex(where: { $0.id == contractId }) {
                proContracts[index].status = .cancelled
            }
            
            successMessage = "Contract cancelled"
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Payment Actions
    
    public func createEscrow(for contract: Contract, method: Escrow.PaymentMethod) async -> Escrow? {
        do {
            isLoading = true
            let request = EscrowRequest(
                contractId: contract.id!,
                method: method,
                milestones: contract.milestones
            )
            let escrow = try await service.createEscrow(request)
            successMessage = "Payment secured!"
            isLoading = false
            return escrow
        } catch {
            handleError(error)
            return nil
        }
    }
    
    public func releaseMilestone(escrowId: String, milestoneId: String) async {
        do {
            isLoading = true
            try await service.releaseMilestone(escrowId: escrowId, milestoneId: milestoneId)
            successMessage = "Milestone payment released!"
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Review Actions
    
    public func submitReview(for contractId: String, rating: Int, text: String?) async {
        do {
            isLoading = true
            let review = NewReview(contractId: contractId, rating: rating, text: text)
            _ = try await service.createReview(review)
            successMessage = "Thank you for your review!"
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Messaging
    
    public func sendMessage(threadId: String, text: String, attachments: [String] = []) async {
        do {
            let message = try await service.sendMessage(
                threadId: threadId,
                text: text,
                attachments: attachments
            )
            messages.append(message)
        } catch {
            handleError(error)
        }
    }
    
    public func loadMessages(threadId: String) async {
        do {
            messages = try await service.getMessages(threadId: threadId)
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Pro Profile
    
    public func updateProProfile(_ profile: ProProfile) async {
        do {
            isLoading = true
            proProfile = try await service.updateProProfile(profile)
            successMessage = "Profile updated successfully!"
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    public func searchPros(categoryId: String, city: String) async -> [ProProfile] {
        do {
            return try await service.searchPros(categoryId: categoryId, city: city)
        } catch {
            handleError(error)
            return []
        }
    }
    
    // MARK: - Dispute Actions
    
    public func createDispute(contractId: String, reason: String, evidence: [String]) async {
        do {
            isLoading = true
            _ = try await service.createDispute(
                contractId: contractId,
                reason: reason,
                evidence: evidence
            )
            successMessage = "Dispute submitted. We'll review it shortly."
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleRFQUpdate(_ rfq: RFQ) {
        if let index = myRFQs.firstIndex(where: { $0.id == rfq.id }) {
            myRFQs[index] = rfq
        }
    }
    
    private func handleBidUpdate(_ bid: Bid) {
        if let index = currentRFQBids.firstIndex(where: { $0.id == bid.id }) {
            currentRFQBids[index] = bid
        }
    }
    
    private func handleContractUpdate(_ contract: Contract) {
        if let index = myContracts.firstIndex(where: { $0.id == contract.id }) {
            myContracts[index] = contract
        } else if let index = proContracts.firstIndex(where: { $0.id == contract.id }) {
            proContracts[index] = contract
        }
    }
    
    private func handleError(_ error: Error) {
        isLoading = false
        if let homeError = error as? HomeServicesError {
            errorMessage = homeError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        
        // Clear error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.errorMessage = nil
        }
    }
    
    public func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}