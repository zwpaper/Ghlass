import Foundation
import SwiftUI

@MainActor
class AppViewModel: ObservableObject {
    @Published var notifications: [GitHubNotification] = []
    @Published var selectedNotificationIds: Set<String> = []
    @Published var selectedNotificationId: String? = nil // For 3-column selection
    
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Details Cache
    @Published var detailsCache: [String: GitHubResourceDetail] = [:]
    @Published var commentsCache: [String: [GitHubComment]] = [:]
    @Published var loadingDetails: Set<String> = []
    
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
                return false
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
    }
    
    func fetchNotifications() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await GitHubService.shared.fetchNotifications()
            self.notifications = fetched
            
            // Pre-fetch details for visible notifications if needed, or do it on appear of rows
            // For now, let's just fetch notifications.
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
        // Optimistic update: remove from list immediately
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
        if detailsCache[url] != nil { return }
        if loadingDetails.contains(url) { return }
        
        loadingDetails.insert(url)
        do {
            let detail = try await GitHubService.shared.fetchResourceDetail(url: url)
            detailsCache[url] = detail
            
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