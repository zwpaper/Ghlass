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
    @Published var checkSuiteCache: [String: GitHubCheckSuiteDetail] = [:]
    @Published var releaseCache: [String: GitHubRelease] = [:]
    @Published var jobsCache: [Int: [GitHubJob]] = [:] // Key: Run ID
    @Published var loadingDetails: Set<String> = []
    @Published var failedDetails: [String: String] = [:] // URL -> Error message

    // Filters
    @Published var selectedRepos: Set<String> = []
    @Published var selectedTypes: Set<String> = []
    @Published var showUnreadOnly = true
    @Published var showOpenOnly = false

    // Auto-Sync
    @Published var syncInterval: Int {
        didSet {
            UserDefaults.standard.set(syncInterval, forKey: "syncInterval")
            startAutoSync()
        }
    }
    private var timer: Timer?

    init() {
        self.syncInterval = UserDefaults.standard.integer(forKey: "syncInterval")
        if self.syncInterval == 0 { self.syncInterval = 10 } // Default to 10 minutes
        startAutoSync()
    }

    func startAutoSync() {
        stopAutoSync()
        guard syncInterval > 0 else { return }

        print("Starting auto-sync with interval: \(syncInterval) minutes")
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(syncInterval * 60), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                print("Auto-syncing notifications...")
                await self?.fetchNotifications()
            }
        }
    }

    func stopAutoSync() {
        timer?.invalidate()
        timer = nil
    }

    // Computed properties for filters

    // Helper to get non-archived notifications
    var activeNotifications: [GitHubNotification] {
        notifications.filter { !$0.isDone }
    }

    var availableRepos: [String] {
        Array(Set(activeNotifications.map { $0.repository.fullName })).sorted()
    }

    var availableTypes: [String] {
        Array(Set(activeNotifications.map { $0.subject.type })).sorted()
    }

    func countForRepo(_ repo: String) -> Int {
        activeNotifications.filter { $0.repository.fullName == repo }.count
    }

    func countForType(_ type: String) -> Int {
        activeNotifications.filter { $0.subject.type == type }.count
    }

    var unreadCount: Int {
        activeNotifications.filter { $0.unread }.count
    }

    var openCount: Int {
        activeNotifications.filter { notification in
            if let url = notification.subject.url, let detail = detailsCache[url] {
                return detail.state == "open"
            }
            return true
        }.count
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

            // Archived/Done Filter
            // Even when "Unread Only" is unchecked, we should not show archived notifications
            if notification.isDone {
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

    var displayItems: [NotificationDisplayItem] {
        let filtered = filteredNotifications
        var groups: [String: [GitHubNotification]] = [:] // Key: "repo|normalizedTitle"
        var singles: [GitHubNotification] = []

        for notification in filtered {
            if notification.subject.type == "CheckSuite" {
                let normalizedTitle = normalizeCheckSuiteTitle(notification.subject.title)
                let key = "\(notification.repository.fullName)|\(normalizedTitle)"
                groups[key, default: []].append(notification)
            } else {
                singles.append(notification)
            }
        }

        var items: [NotificationDisplayItem] = []

        // Add singles
        for n in singles {
            items.append(.notification(n))
        }

        // Add groups
        for (key, notifs) in groups {
            // Extract title from key
            let title = String(key.split(separator: "|", maxSplits: 1).last ?? "")
            items.append(.group(title: title, notifications: notifs))
        }

        // Sort by updatedAt
        return items.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func normalizeCheckSuiteTitle(_ title: String) -> String {
        // Remove ", Attempt #N" or " Attempt #N"
        // Example: "Pochi Integration test workflow run, Attempt #3 failed for main branch"
        // Becomes: "Pochi Integration test workflow run failed for main branch"

        var normalized = title

        // Regex to match ", Attempt #\d+" or " Attempt #\d+"
        // We use a simple replacement approach
        // Note: NSRegularExpression is robust

        if let regex = try? NSRegularExpression(pattern: ",? Attempt #\\d+", options: .caseInsensitive) {
            let range = NSRange(location: 0, length: normalized.utf16.count)
            normalized = regex.stringByReplacingMatches(in: normalized, options: [], range: range, withTemplate: "")
        }

        // Clean up double spaces if any created (though template is empty string, so "run, Attempt #3 failed" -> "run failed")
        // If "run Attempt #3 failed" -> "run failed"

        return normalized.replacingOccurrences(of: "  ", with: " ")
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
            var reposToSync: Set<String> = []

            for notification in fetched {
                DatabaseService.shared.upsertNotificationThread(notification)
                reposToSync.insert(notification.repository.fullName)

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

            // Sync action runs for relevant repositories
            await syncActionRuns(for: reposToSync)

            // 4. Load from DB to UI
            self.notifications = DatabaseService.shared.getAllNotificationThreads()

            // 5. Load details from DB to cache so UI shows correct status icons
            let localDetails = DatabaseService.shared.getAllIssueDetails()
            self.detailsCache.merge(localDetails) { (_, new) in new }

        } catch {
            self.errorMessage = error.localizedDescription
            // Even if fetch fails, load from DB
            self.notifications = DatabaseService.shared.getAllNotificationThreads()

            let localDetails = DatabaseService.shared.getAllIssueDetails()
            self.detailsCache.merge(localDetails) { (_, new) in new }
        }
        isLoading = false
    }

    func markSelectedAsDone() async {
        let idsToMark = resolveNotificationIds(from: selectedNotificationIds)
        await markAsDone(ids: Array(idsToMark))
    }

    func resolveNotificationIds(from ids: Set<String>) -> Set<String> {
        var result = Set<String>()
        // We need to look up in displayItems to find groups
        let currentItems = displayItems

        for id in ids {
            if id.hasPrefix("group|") {
                // Find the group
                if let item = currentItems.first(where: { $0.id == id }),
                   case .group(_, let notifications) = item {
                    result.formUnion(notifications.map(\.id))
                }
            } else {
                result.insert(id)
            }
        }
        return result
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

        let cacheKey = notification.cacheKey
        let url = notification.subject.url

        if notification.subject.type != "CheckSuite" {
            guard let validUrl = url, !validUrl.isEmpty else {
                print("⚠️ No subject URL for notification: \(notification.subject.title) (ID: \(notification.id))")
                return
            }
        }

        // 1. Check if already loading to prevent duplicate requests
        if loadingDetails.contains(cacheKey) {
            print("⏳ Already loading details for: \(notification.subject.title)")
            return
        }

        // 2. Mark as loading and clear any previous errors
        loadingDetails.insert(cacheKey)
        failedDetails.removeValue(forKey: cacheKey)

        print("🔄 Fetching details for: \(notification.subject.title)")
        print("   Type: \(notification.subject.type)")
        print("   URL: \(url ?? "nil")")

        do {
            if notification.subject.type == "CheckSuite" {
                // Try to match with a workflow run
                let matchedRun = await findMatchedWorkflowRun(notification: notification)

                checkSuiteCache[cacheKey] = GitHubCheckSuiteDetail(
                    workflowRun: matchedRun
                )
                print("✓ Fetched check suite details (from local DB)")

                if let run = matchedRun {
                    Task {
                        await fetchJobs(for: run, repoFullName: notification.repository.fullName)
                    }
                }
            } else if notification.subject.type == "Release" {
                // Fetch release details
                let detailUrl = url!
                let release = try await GitHubService.shared.fetchRelease(url: detailUrl)
                releaseCache[cacheKey] = release
                print("✓ Fetched release: \(release.tagName)")
            } else {
                // 3. Fetch latest details from GitHub API
                // We know url is not nil here due to the guard above
                let detailUrl = url!
                let detail = try await GitHubService.shared.fetchResourceDetail(url: detailUrl)
                detailsCache[cacheKey] = detail
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
                var allComments: [GitHubComment] = []

                if notification.subject.type == "PullRequest" {
                    // For PRs, we want both review comments (code) and issue comments (conversation)
                    let reviewCommentsUrl = detailUrl + "/comments"
                    // Construct Issue URL from Pull URL: .../pulls/123 -> .../issues/123
                    let issueCommentsUrl = detailUrl.replacingOccurrences(of: "/pulls/", with: "/issues/") + "/comments"

                    print("🔄 Fetching PR comments from: \(reviewCommentsUrl) and \(issueCommentsUrl)")

                    // Fetch in parallel
                    async let reviewCommentsTask = GitHubService.shared.fetchComments(commentsUrl: reviewCommentsUrl)
                    async let issueCommentsTask = GitHubService.shared.fetchComments(commentsUrl: issueCommentsUrl)

                    let reviews = try await reviewCommentsTask
                    let issues = try await issueCommentsTask
                    allComments = reviews + issues
                } else {
                    let commentsUrl = detailUrl + "/comments"
                    print("🔄 Fetching comments from: \(commentsUrl)")
                    allComments = try await GitHubService.shared.fetchComments(commentsUrl: commentsUrl)
                }

                allComments.sort { $0.createdAt < $1.createdAt }
                commentsCache[cacheKey] = allComments
                print("✓ Fetched \(allComments.count) comments")
            }

            // 6. Clear loading state
            loadingDetails.remove(cacheKey)

            print("✅ Successfully loaded details for: \(notification.subject.title)")

        } catch {
            print("❌ Failed to fetch details for \(url ?? "nil"): \(error)")
            if let serviceError = error as? GitHubService.ServiceError {
                failedDetails[cacheKey] = serviceError.errorDescription ?? "Unknown error"
            } else {
                failedDetails[cacheKey] = error.localizedDescription
            }
            loadingDetails.remove(cacheKey)
        }
    }

    func fetchJobs(for run: GitHubWorkflowRun, repoFullName: String) async {
        // Check if already loaded? Maybe we want to refresh.
        // For now, let's just fetch.

        do {
            print("🔄 Fetching jobs for run #\(run.id)")
            let jobs = try await GitHubService.shared.fetchWorkflowJobs(repoFullName: repoFullName, runId: run.id)
            jobsCache[run.id] = jobs
            print("✓ Fetched \(jobs.count) jobs for run #\(run.id)")
        } catch {
            print("❌ Failed to fetch jobs for run #\(run.id): \(error)")
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

    // MARK: - Action Runs Support

    private func syncActionRuns(for repos: Set<String>) async {
        for repo in repos {
            let lastSync = DatabaseService.shared.getLastActionRunSyncTime(repoFullName: repo)
            do {
                let runs = try await GitHubService.shared.fetchWorkflowRuns(repoFullName: repo, since: lastSync)
                for run in runs {
                    DatabaseService.shared.upsertActionRun(run, repoFullName: repo)
                }

                // Update sync time if we got results, or just update to now?
                // If we use 'since', we should probably update to the latest created_at we got, or 'now' if we trust the API.
                // Using 'now' is safer to avoid gaps if we assume the API returns everything up to now.
                DatabaseService.shared.updateLastActionRunSyncTime(repoFullName: repo, date: Date())
                print("Synced \(runs.count) action runs for \(repo)")
            } catch {
                print("Failed to sync action runs for \(repo): \(error)")
            }
        }
    }

    private func findMatchedWorkflowRun(notification: GitHubNotification) async -> GitHubWorkflowRun? {
        // Parse title: "Name workflow run status for branch branch"
        // Example: "Pochi Integration test workflow run failed for main branch"
        let title = notification.subject.title

        // 1. Extract Workflow Name
        // Split by " workflow run "
        let parts = title.components(separatedBy: " workflow run ")
        guard parts.count >= 2 else { return nil }

        let workflowName = parts[0].trimmingCharacters(in: .whitespaces)

        // 2. Extract Branch Name
        // Remainder: "failed for main branch" (or similar status)
        let rest = parts[1]

        // Split by " for " to separate status from branch
        // We take the last component to handle potential " for " in status (though unlikely)
        let statusAndBranch = rest.components(separatedBy: " for ")
        guard statusAndBranch.count >= 2 else { return nil }

        // The last part should be "{branchName} branch"
        var branchPart = statusAndBranch.last!
        if branchPart.hasSuffix(" branch") {
            branchPart = String(branchPart.dropLast(7))
        }
        let branchName = branchPart.trimmingCharacters(in: .whitespaces)

        // 3. Query DB for runs in this repo
        let runs = DatabaseService.shared.getActionRuns(repoFullName: notification.repository.fullName, branch: branchName)

        // 4. Filter by name and branch
        let candidates = runs.filter { run in
            run.name == workflowName
        }

        // 5. Find the run closest in time to the notification
        // We allow a tolerance (e.g., 1 minutes) because notification time and run time may differ slightly
        let notificationTime = notification.updatedAt

        let matched = candidates.filter { run in
            let diff = abs(run.updatedAt.timeIntervalSince(notificationTime))
            return diff <= 60 // 1 minutes tolerance
        }.min(by: {
            abs($0.updatedAt.timeIntervalSince(notificationTime)) < abs($1.updatedAt.timeIntervalSince(notificationTime))
        })

        print("Matched run: \(matched?.htmlUrl ?? "nil")")

        return matched
    }
}

enum NotificationDisplayItem: Identifiable, Hashable {
    case notification(GitHubNotification)
    case group(title: String, notifications: [GitHubNotification])

    var id: String {
        switch self {
        case .notification(let n):
            return n.id
        case .group(let title, let notifications):
            let repo = notifications.first?.repository.fullName ?? ""
            return "group|\(repo)|\(title)"
        }
    }

    var updatedAt: Date {
        switch self {
        case .notification(let n): return n.updatedAt
        case .group(_, let notifications):
            return notifications.map(\.updatedAt).max() ?? Date.distantPast
        }
    }

    var unread: Bool {
        switch self {
        case .notification(let n): return n.unread
        case .group(_, let notifications):
            return notifications.contains { $0.unread }
        }
    }
}
