import UIKit
import Social
import MobileServices
import MealPlanningService

class ShareViewController: SLComposeServiceViewController {
    
    private let mealPlanningService = MealPlanningServiceFactory.createService()
    private var sharedURL: URL?
    
    override func isContentValid() -> Bool {
        return sharedURL != nil
    }
    
    override func didSelectPost() {
        if let url = sharedURL {
            importRecipe(from: url)
        } else {
            extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    override func configurationItems() -> [Any]! {
        // Return an array of SLComposeSheetConfigurationItem to customize the UI
        return []
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Extract URL from share context
        extractSharedURL()
        
        // Customize the UI
        title = "Add Recipe to Liive"
        placeholder = "Add a note about this recipe (optional)"
        
        // Detect platform and update UI accordingly
        if let url = sharedURL {
            updateUIForPlatform(url)
        }
    }
    
    private func extractSharedURL() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            return
        }
        
        if itemProvider.hasItemConformingToTypeIdentifier("public.url") {
            itemProvider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (item, error) in
                if let url = item as? URL {
                    DispatchQueue.main.async {
                        self?.sharedURL = url
                        self?.validateContent()
                    }
                }
            }
        } else if itemProvider.hasItemConformingToTypeIdentifier("public.plain-text") {
            itemProvider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] (item, error) in
                if let text = item as? String, let url = URL(string: text) {
                    DispatchQueue.main.async {
                        self?.sharedURL = url
                        self?.validateContent()
                    }
                }
            }
        }
    }
    
    private func updateUIForPlatform(_ url: URL) {
        let urlString = url.absoluteString.lowercased()
        
        if urlString.contains("instagram.com") {
            title = "Add Instagram Recipe"
            placeholder = "Instagram recipe from @\(extractUsername(from: url) ?? "unknown")"
        } else if urlString.contains("tiktok.com") {
            title = "Add TikTok Recipe"
            placeholder = "TikTok recipe - add your notes here"
        } else if urlString.contains("youtube.com") || urlString.contains("youtu.be") {
            title = "Add YouTube Recipe"
            placeholder = "YouTube recipe - add your notes here"
        } else {
            title = "Add Web Recipe"
            placeholder = "Recipe from \(url.host ?? "web")"
        }
    }
    
    private func extractUsername(from url: URL) -> String? {
        // Simple Instagram username extraction
        let pathComponents = url.pathComponents
        if pathComponents.count > 1 {
            return pathComponents[1].replacingOccurrences(of: "/", with: "")
        }
        return nil
    }
    
    private func importRecipe(from url: URL) {
        // Show loading state
        navigationController?.view.isUserInteractionEnabled = false
        
        Task {
            do {
                let recipeId = try await mealPlanningService.importRecipe(from: url.absoluteString)
                
                DispatchQueue.main.async { [weak self] in
                    self?.showSuccess(recipeId: recipeId)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.showError(error: error)
                }
            }
        }
    }
    
    private func showSuccess(recipeId: String) {
        let alert = UIAlertController(
            title: "Recipe Added! 🍽️",
            message: "Your recipe is being processed and will be available in the Liive app shortly.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
            self?.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
        })
        
        present(alert, animated: true)
    }
    
    private func showError(error: Error) {
        navigationController?.view.isUserInteractionEnabled = true
        
        let alert = UIAlertController(
            title: "Import Failed",
            message: "We couldn't import this recipe. Please try again or copy the URL and import it directly in the Liive app.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
            if let url = self?.sharedURL {
                self?.importRecipe(from: url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.extensionContext!.cancelRequest(withError: error)
        })
        
        present(alert, animated: true)
    }
}