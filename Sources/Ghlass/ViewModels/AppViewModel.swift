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
                let isSelected = (selectedNotificationId == notification.id) || selectedNotificationIds.contains(notification.id)
                let isLastRead = (lastReadNotificationId == notification.id)
                
                if !isSelected && !isLastRead {
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
            let fetched = try await GitHubService.shared.fetchNotifications()
            self.notifications = fetched.filter { 
                DatabaseService.shared.shouldShowNotification(notificationId: $0.id, currentUpdatedAt: $0.updatedAt)
            }
        } catch {
            self.errorMessage = "Failed to fetch notifications: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func markSelectedAsDone() async {
        let idsToMark = selectedNotificationIds
        await markAsDone(ids: Array(idsToMark))
    }
    
    func markAsDone(ids: [String]) async {
        // Save state to DB
        let itemsToMark = notifications.filter { ids.contains($0.id) }
        for item in itemsToMark {
            DatabaseService.shared.markNotificationAsDone(notificationId: item.id, updatedAt: item.updatedAt)
        }

        // Optimistic update: always remove from list as requested
        notifications.removeAll { ids.contains($0.id) }
        
        // Clear selection if needed
        selectedNotificationIds.subtract(ids)
        if let selected = selectedNotificationId, ids.contains(selected) {
            selectedNotificationId = nil
        }
        
        // Perform API calls
        for id in ids {
            do {
                try await GitHubService.shared.markAsDone(notificationId: id)
            } catch {
                print("Failed to mark notification \(id) as done: \(error)")
                // In a robust app, we might restore the item on failure
            }
        }
    }
    
    func fetchDetail(for notification: GitHubNotification) async {
        guard let url = notification.subject.url else { return }
        
        if detailsCache[url] != nil {
            if notification.unread {
                Task {
                    try? await GitHubService.shared.markAsRead(notificationId: notification.id)
                    await MainActor.run {
                        // Set lastReadNotificationId BEFORE modifying the notification to ensure
                        // the filter logic sees it as "last read" during the update cycle.
                        self.lastReadNotificationId = notification.id
                        
                        if let index = self.notifications.firstIndex(where: { $0.id == notification.id }) {
                            self.notifications[index] = self.notifications[index].markedAsRead()
                        }
                    }
                }
            }
            return
        }
        
        if loadingDetails.contains(url) { return }
        
        // Clear any previous failure for this URL
        failedDetails.removeValue(forKey: url)
        
        loadingDetails.insert(url)
        do {
            let detail = try await GitHubService.shared.fetchResourceDetail(url: url)
            detailsCache[url] = detail
            
            if notification.unread {
                Task {
                    try? await GitHubService.shared.markAsRead(notificationId: notification.id)
                    await MainActor.run {
                        // Set lastReadNotificationId BEFORE modifying the notification to ensure
                        // the filter logic sees it as "last read" during the update cycle.
                        self.lastReadNotificationId = notification.id
                        
                        if let index = self.notifications.firstIndex(where: { $0.id == notification.id }) {
                            self.notifications[index] = self.notifications[index].markedAsRead()
                        }
                    }
                }
            }
            
            // Fetch comments if needed
            // Construct comments URL: usually url + "/comments"
            // But let's check if we can get it from somewhere else or just append.
            // The GitHub API consistency: issues/123 -> issues/123/comments
            // PRs are issues in terms of comments mostly.
            let commentsUrl = url + "/comments"
            let comments = try await GitHubService.shared.fetchComments(commentsUrl: commentsUrl)
            commentsCache[url] = comments
            
        } catch {
            print("Failed to fetch details for \(url): \(error)")
            failedDetails[url] = error.localizedDescription
        }
        loadingDetails.remove(url)
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