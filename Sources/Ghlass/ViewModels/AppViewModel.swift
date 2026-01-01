import Foundation
import SwiftUI

@MainActor
class AppViewModel: ObservableObject {
    @Published var notifications: [GitHubNotification] = []
    @Published var selectedNotificationIds: Set<String> = []
    @Published var selectedNotificationId: String? = nil // For 3-column selection
    @Published var lastReadNotificationId: String? = nil // To keep the currently viewed notification visible
    
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Details Cache
    @Published var detailsCache: [String: GitHubResourceDetail] = [:]
    @Published var commentsCache: [String: [GitHubComment]] = [:]
    @Published var loadingDetails: Set<String> = []
    @Published var failedDetails: [String: String] = [:] // URL -> Error message
    
    // Filters
    @Published var selectedRepos: Set<String> = []
    @Published var selectedTypes: Set<String> = []
    @Published var showUnreadOnly = true
    @Published var showOpenOnly = false
    
    // Computed properties for filters
    var availableRepos: [String] {
        Array(Set(notifications.map { $0.repository.fullName })).sorted()
    }
    
    var availableTypes: [String] {
        Array(Set(notifications.map { $0.subject.type })).sorted()
    }
    
    func countForRepo(_ repo: String) -> Int {
        notifications.filter { $0.repository.fullName == repo }.count
    }
    
    func countForType(_ type: String) -> Int {
        notifications.filter { $0.subject.type == type }.count
    }
    
    var filteredNotifications: [GitHubNotification] {
        notifications.filter { notification in
            // Repo Filter
            if !selectedRepos.isEmpty && !selectedRepos.contains(notification.repository.fullName) {
                return false
            }
            
            // Type Filter
            if !selectedTypes.isEmpty && !selectedTypes.contains(notification.subject.type) {
                return false
            }
            
            // Unread Filter
            if showUnreadOnly && !notification.unread {
                // Keep the currently selected/viewed notification visible even if read
                let isSelected = (selectedNotificationId == notification.id)
                
                // We want the item to disappear when we select another one.
                // So we only keep it if it is the CURRENTLY selected one.
                
                if !isSelected {
                    return false
                }
            }
            
            // Open State Filter (requires detail to be loaded to be accurate, or we assume open if unknown?)
            // For now, let's only filter if we KNOW it's closed.
            if showOpenOnly {
                if let url = notification.subject.url, let detail = detailsCache[url] {
                    if detail.state != "open" {
                        return false
                    }
                }
            }
            
            return true
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    func fetchNotifications() async {
        isLoading = true
        errorMessage = nil
        do {
            // 1. Sync: Get last sync time from DB
            let lastSync = DatabaseService.shared.getLastSyncTime()
            
            // 2. Fetch from GitHub
            let fetched = try await GitHubService.shared.fetchNotifications(since: lastSync)
            
            // 3. Upsert threads to DB and fetch details for Issues/PRs
            for notification in fetched {
                DatabaseService.shared.upsertNotificationThread(notification)
                
                // Fetch details if Issue or PR
                if (notification.subject.type == "Issue" || notification.subject.type == "PullRequest"),
                   let url = notification.subject.url {
                    
                    // We need to fetch detail to get title, state, etc.
                    // Note: GitHubService.fetchResourceDetail returns GitHubResourceDetail
                    // We need to pass repoFullName, number, type to upsertIssuePr
                    // notification.repository.fullName is available
                    // notification.subjectId gives the number (usually)
                    
                    if let numberString = notification.subjectId, let number = Int(numberString) {
                        do {
                            let detail = try await GitHubService.shared.fetchResourceDetail(url: url)
                            DatabaseService.shared.upsertIssuePr(
                                issue: detail,
                                repoFullName: notification.repository.fullName,
                                number: number,
                                type: notification.subject.type
                            )
                        } catch {
                            print("Failed to sync detail for \(url): \(error)")
                        }
                    }
                }
            }
            
            // 4. Load from DB to UI
            self.notifications = DatabaseService.shared.getAllNotificationThreads()
            
            // 5. Load details from DB to cache so UI shows correct status icons
            let localDetails = DatabaseService.shared.getAllIssueDetails()
            self.detailsCache.merge(localDetails) { (_, new) in new }
            
        } catch {
            self.errorMessage = "Failed to fetch notifications: \(error.localizedDescription)"
            // Even if fetch fails, load from DB
            self.notifications = DatabaseService.shared.getAllNotificationThreads()
            
            let localDetails = DatabaseService.shared.getAllIssueDetails()
            self.detailsCache.merge(localDetails) { (_, new) in new }
        }
        isLoading = false
    }
    
    func markSelectedAsDone() async {
        let idsToMark = selectedNotificationIds
        await markAsDone(ids: Array(idsToMark))
    }
    
    func markAsDone(ids: [String]) async {
        // Save state to DB
        for id in ids {
            DatabaseService.shared.markNotificationAsDone(threadId: id)
        }

        // Optimistic update
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            notifications.removeAll { ids.contains($0.id) }
            
            // Clear selection if needed
            selectedNotificationIds.subtract(ids)
            if let selected = selectedNotificationId, ids.contains(selected) {
                selectedNotificationId = nil
            }
        }
        
        for id in ids {
            Task {
                try? await GitHubService.shared.markAsDone(notificationId: id)
            }
        }
    }

    func markAsRead(id: String) async {
        // 1. Update local DB
        DatabaseService.shared.markNotificationAsRead(threadId: id)
        
        // 2. Update memory (notifications array) so UI reflects change
        // We need to update the `unread` property of the item in `notifications`
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            var updated = notifications[index]
            // We can't set `unread` directly if it's let, but we can reconstruct
            // Actually GitHubNotification is a struct, we can use the helper or create new
            updated = updated.markedAsRead()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                notifications[index] = updated
            }
        }
        
        // 3. Sync to GitHub (mark as read)
        Task {
            try? await GitHubService.shared.markAsRead(notificationId: id)
        }
    }
    
    func fetchDetail(for notification: GitHubNotification) async {
        // Fetch latest details and comments from GitHub API when a notification is selected
        guard let url = notification.subject.url else {
            print("⚠️ No subject URL for notification: \(notification.subject.title)")
            return
        }
        
        // 1. Check if already loading to prevent duplicate requests
        if loadingDetails.contains(url) {
            print("⏳ Already loading details for: \(notification.subject.title)")
            return
        }
        
        // 2. Mark as loading and clear any previous errors
        loadingDetails.insert(url)
        failedDetails.removeValue(forKey: url)
        
        print("🔄 Fetching details for: \(notification.subject.title)")
        print("   Type: \(notification.subject.type)")
        print("   URL: \(url)")
        
        do {
            // 3. Fetch latest details from GitHub API
            let detail = try await GitHubService.shared.fetchResourceDetail(url: url)
            detailsCache[url] = detail
            print("✓ Fetched detail - State: \(detail.state), Number: \(detail.number)")
            
            // 4. Update DB if it's an Issue/PR
            if (notification.subject.type == "Issue" || notification.subject.type == "PullRequest"),
               let numberString = notification.subjectId, let number = Int(numberString) {
                DatabaseService.shared.upsertIssuePr(
                    issue: detail,
                    repoFullName: notification.repository.fullName,
                    number: number,
                    type: notification.subject.type
                )
                print("✓ Updated DB for \(notification.subject.type) #\(number)")
            }
            
            // 5. Fetch comments from GitHub API
            let commentsUrl = url + "/comments"
            print("🔄 Fetching comments from: \(commentsUrl)")
            let comments = try await GitHubService.shared.fetchComments(commentsUrl: commentsUrl)
            commentsCache[url] = comments
            print("✓ Fetched \(comments.count) comments")
            
            // 6. Clear loading state
            loadingDetails.remove(url)
            
            print("✅ Successfully loaded details and comments for: \(notification.subject.title)")
            
        } catch {
            print("❌ Failed to fetch details for \(url): \(error)")
            if let serviceError = error as? GitHubService.ServiceError {
                failedDetails[url] = serviceError.errorDescription ?? "Unknown error"
            } else {
                failedDetails[url] = error.localizedDescription
            }
            loadingDetails.remove(url)
        }
    }
    
    func toggleRepoFilter(_ repo: String) {
        if selectedRepos.contains(repo) {
            selectedRepos.remove(repo)
        } else {
            selectedRepos.insert(repo)
        }
    }
    
    func toggleTypeFilter(_ type: String) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }
}