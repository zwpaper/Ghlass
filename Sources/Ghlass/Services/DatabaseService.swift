import Foundation
import SQLite

class DatabaseService {
    static let shared = DatabaseService()

    private var db: Connection?

    // Tables
    private let notificationThreadTable = Table("notification_thread")
    private let localNotificationStateTable = Table("local_notification_state")
    private let issuePrTable = Table("issue_pr")
    private let actionRunTable = Table("action_run")
    private let repoSyncStateTable = Table("repo_sync_state")

    // notification_thread columns
    private let nt_id = Expression<String>("id")
    private let nt_repository = Expression<String>("repository") // JSON
    private let nt_subject_type = Expression<String>("subject_type")
    private let nt_subject_id = Expression<Int?>("subject_id")
    private let nt_subject_url = Expression<String>("subject_url")
    private let nt_title = Expression<String?>("title")
    private let nt_reason = Expression<String>("reason")
    private let nt_updated_at = Expression<Date>("updated_at")
    private let nt_last_synced_at = Expression<Date>("last_synced_at")

    // local_notification_state columns
    private let lns_thread_id = Expression<String>("thread_id")
    private let lns_is_done = Expression<Bool>("is_done")
    private let lns_done_at = Expression<Date?>("done_at")
    private let lns_is_read = Expression<Bool>("is_read")
    private let lns_is_snoozed = Expression<Bool>("is_snoozed")
    private let lns_snoozed_until = Expression<Date?>("snoozed_until")
    private let lns_is_pinned = Expression<Bool>("is_pinned")

    // issue_pr columns
    private let ip_id = Expression<Int64>("id")
    private let ip_repo = Expression<String>("repo")
    private let ip_number = Expression<Int>("number")
    private let ip_type = Expression<String>("type") // issue | pr
    private let ip_state = Expression<String>("state")
    private let ip_title = Expression<String>("title")
    private let ip_assignees = Expression<String?>("assignees") // JSON
    private let ip_author = Expression<String?>("author") // JSON
    private let ip_labels = Expression<String?>("labels") // JSON
    private let ip_comments = Expression<Int>("comments")
    private let ip_review_comments = Expression<Int?>("review_comments")
    private let ip_merged_by = Expression<String?>("merged_by") // JSON
    private let ip_merged_at = Expression<Date?>("merged_at")
    private let ip_created_at = Expression<Date?>("created_at")
    private let ip_updated_at = Expression<Date>("updated_at")
    private let ip_last_synced_at = Expression<Date>("last_synced_at")

    // action_run columns
    private let ar_id = Expression<Int64>("id")
    private let ar_repo = Expression<String>("repo")
    private let ar_name = Expression<String>("name")
    private let ar_head_branch = Expression<String>("head_branch")
    private let ar_head_sha = Expression<String>("head_sha")
    private let ar_status = Expression<String?>("status")
    private let ar_conclusion = Expression<String?>("conclusion")
    private let ar_created_at = Expression<Date>("created_at")
    private let ar_updated_at = Expression<Date>("updated_at")
    private let ar_html_url = Expression<String>("html_url")
    private let ar_run_number = Expression<Int>("run_number")
    private let ar_event = Expression<String>("event")

    // repo_sync_state columns
    private let rss_repo = Expression<String>("repo")
    private let rss_last_run_sync = Expression<Date?>("last_run_sync")

    private init() {
        do {
            let fileManager = FileManager.default
            guard let documentsURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                print("Could not access documents directory")
                return
            }
            print(documentsURL.path)

            let dbPath = documentsURL.appendingPathComponent("ghlass.sqlite3").path
            db = try Connection(dbPath)
            createTables()
        } catch {
            print("Database initialization failed: \(error)")
        }
    }

    private func createTables() {
        guard let db = db else { return }

        do {
            try db.run(notificationThreadTable.create(ifNotExists: true) { t in
                t.column(nt_id, primaryKey: true)
                t.column(nt_repository)
                t.column(nt_subject_type)
                t.column(nt_subject_id)
                t.column(nt_subject_url)
                t.column(nt_title)
                t.column(nt_reason)
                t.column(nt_updated_at)
                t.column(nt_last_synced_at)
            })

            // Migration: Add title column if it doesn't exist
            try? db.run(notificationThreadTable.addColumn(nt_title))

            try db.run(localNotificationStateTable.create(ifNotExists: true) { t in
                t.column(lns_thread_id, primaryKey: true)
                t.column(lns_is_done)
                t.column(lns_done_at)
                t.column(lns_is_read, defaultValue: false)
                t.column(lns_is_snoozed)
                t.column(lns_snoozed_until)
                t.column(lns_is_pinned, defaultValue: false)
            })

            // Migration: Add is_read column if it doesn't exist
            // try? db.run(localNotificationStateTable.addColumn(lns_is_read, defaultValue: false))
            try? db.run(localNotificationStateTable.addColumn(lns_is_pinned, defaultValue: false))

            try db.run(issuePrTable.create(ifNotExists: true) { t in
                t.column(ip_id, primaryKey: true)
                t.column(ip_repo)
                t.column(ip_number)
                t.column(ip_type)
                t.column(ip_state)
                t.column(ip_title)
                t.column(ip_assignees)
                t.column(ip_author)
                t.column(ip_labels)
                t.column(ip_comments, defaultValue: 0)
                t.column(ip_review_comments)
                t.column(ip_merged_by)
                t.column(ip_merged_at)
                t.column(ip_created_at)
                t.column(ip_updated_at)
                t.column(ip_last_synced_at)
            })
            
            // Migration: Add labels column if it doesn't exist
             try? db.run(issuePrTable.addColumn(ip_labels))
             try? db.run(issuePrTable.addColumn(ip_comments, defaultValue: 0))
             try? db.run(issuePrTable.addColumn(ip_review_comments))
             try? db.run(issuePrTable.addColumn(ip_merged_by))
             try? db.run(issuePrTable.addColumn(ip_merged_at))
             try? db.run(issuePrTable.addColumn(ip_created_at))

            try db.run(actionRunTable.create(ifNotExists: true) { t in
                t.column(ar_id, primaryKey: true)
                t.column(ar_repo)
                t.column(ar_name)
                t.column(ar_head_branch)
                t.column(ar_head_sha)
                t.column(ar_status)
                t.column(ar_conclusion)
                t.column(ar_created_at)
                t.column(ar_updated_at)
                t.column(ar_html_url)
                t.column(ar_run_number)
                t.column(ar_event)
            })

            try db.run(repoSyncStateTable.create(ifNotExists: true) { t in
                t.column(rss_repo, primaryKey: true)
                t.column(rss_last_run_sync)
            })
        } catch {
            print("Failed to create tables: \(error)")
        }
    }

    // MARK: - Notification Thread

    func upsertNotificationThread(_ notification: GitHubNotification) {
        guard let db = db else { return }

        do {
            let repoJson = jsonString(notification.repository) ?? "{}"
            let insert = notificationThreadTable.insert(or: .replace,
                nt_id <- notification.id,
                nt_repository <- repoJson,
                nt_subject_type <- notification.subject.type,
                nt_subject_id <- Int(notification.subjectId ?? ""),
                nt_subject_url <- (notification.subject.url ?? ""),
                nt_title <- notification.subject.title,
                nt_reason <- notification.reason,
                nt_updated_at <- notification.updatedAt,
                nt_last_synced_at <- Date()
            )
            try db.run(insert)
        } catch {
            print("Failed to upsert notification thread: \(error)")
        }
    }

    func getLastSyncTime() -> Date? {
        guard let db = db else { return nil }
        do {
             let query = notificationThreadTable.select(nt_updated_at.max)
             if let row = try db.pluck(query) {
                 return row[nt_updated_at.max]
             }
             return nil
        } catch {
            print("Failed to get last sync time: \(error)")
            return nil
        }
    }

    func getAllNotificationThreads() -> [GitHubNotification] {
        guard let db = db else { return [] }
        var results: [GitHubNotification] = []

        // Join notification_thread with issue_pr on subject_id
        // Note: subject_id in notification_thread matches id in issue_pr?
        // No, subject_id in notification_thread is likely the issue number or the API ID.
        // GitHubNotification.subjectId is derived from URL. For issues/PRs it is usually the number.
        // But `issue_pr` table has `id` (global ID) and `number`.
        // Let's check `GitHubNotification.subjectId` implementation in models.
        // `subject.url?.components(separatedBy: "/").last` usually gives the NUMBER for issues/prs.
        // So `nt_subject_id` stores the NUMBER.
        // We should join on repo and number.

        // Since SQLite.swift join syntax can be verbose, and we need to reconstruct `GitHubNotification`,
        // let's do a left join to get the title from issue_pr if available.
        // Note: Joining on JSON field is not straightforward in standard SQLite without extensions.
        // We will fetch separately.

        // Wait, `nt_repository` stores JSON, not just the full name. We can't join on it directly unless we extract the name.        // This is a problem with the user's schema request: "repository TEXT" for notification_thread, but usually we need structured data or at least a foreign key.
        // However, I stored the whole repository JSON in `nt_repository`.
        // I cannot easily join on a JSON field in SQLite without JSON extensions (which might not be available or efficient).

        // Workaround: Fetch all threads, and then for those that are issues/PRs, fetch the details from `issue_pr` table separately or in-memory map.
        // Given the dataset size might be small for a personal app, this is acceptable.

        do {
            let threads = try db.prepare(notificationThreadTable.order(nt_updated_at.desc))

            // Pre-fetch all issues/prs to a dictionary for fast lookup?
            // Or just query one by one? One by one is slow.
            // Let's fetch all relevant issue_pr entries.
            // For now, simpler approach: iterate and query if needed, or query all issue_pr.

            // Let's query all issue_pr entries into a dictionary [RepoFullName_Number: Title]
            var titleMap: [String: String] = [:]
            let issues = try db.prepare(issuePrTable.select(ip_repo, ip_number, ip_title))
            for issue in issues {
                let key = "\(issue[ip_repo])_\(issue[ip_number])"
                titleMap[key] = issue[ip_title]
            }

            // Also fetch local state
            var stateMap: [String: (isDone: Bool, isRead: Bool, isSnoozed: Bool, isPinned: Bool)] = [:]
            let states = try db.prepare(localNotificationStateTable)
            for state in states {
                stateMap[state[lns_thread_id]] = (state[lns_is_done], state[lns_is_read], state[lns_is_snoozed], state[lns_is_pinned])
            }

            for row in threads {
                if let repo = try? JSONDecoder().decode(GitHubRepository.self, from: Data(row[nt_repository].utf8)) {
                    let threadId = row[nt_id]
                    // Default state: not done, not read, not snoozed, not pinned
                    let localState = stateMap[threadId] ?? (false, false, false, false)

                    let isDone = localState.isDone
                    let isRead = localState.isRead
                    let isPinned = localState.isPinned

                    // Calculate unread status
                    // If it is done (archived), it is definitely not unread.
                    // If it is marked as read, it is not unread.
                    let isUnread = !isDone && !isRead

                    // Try to find title
                    var title = row[nt_title] ?? ""
                    if let number = row[nt_subject_id] {
                        let key = "\(repo.fullName)_\(number)"
                        if let foundTitle = titleMap[key] {
                            title = foundTitle
                        }
                    }

                    let subject = NotificationSubject(
                        title: title,
                        type: row[nt_subject_type],
                        url: row[nt_subject_url]
                    )

                    let notification = GitHubNotification(
                        id: threadId,
                        repository: repo,
                        subject: subject,
                        reason: row[nt_reason],
                        unread: isUnread,
                        updatedAt: row[nt_updated_at],
                        url: row[nt_subject_url],
                        isDone: isDone,
                        isPinned: isPinned
                    )
                    results.append(notification)
                }
            }
        } catch {
            print("Failed to fetch notifications: \(error)")
        }
        return results
    }

    // MARK: - Local Notification State

    func markNotificationAsDone(threadId: String) {
        guard let db = db else { return }
        do {
            // Update if exists to preserve is_pinned, else insert
            let query = localNotificationStateTable.filter(lns_thread_id == threadId)
            if try db.run(query.update(lns_is_done <- true, lns_done_at <- Date(), lns_is_read <- true)) > 0 {
                // Updated successfully
            } else {
                let insert = localNotificationStateTable.insert(
                    lns_thread_id <- threadId,
                    lns_is_done <- true,
                    lns_done_at <- Date(),
                    lns_is_read <- true,
                    lns_is_snoozed <- false,
                    lns_snoozed_until <- nil,
                    lns_is_pinned <- false
                )
                try db.run(insert)
            }
        } catch {
            print("Failed to mark as done: \(error)")
        }
    }

    func markNotificationAsRead(threadId: String) {
        guard let db = db else { return }
        do {
            // Update if exists, else insert
            let query = localNotificationStateTable.filter(lns_thread_id == threadId)
            if try db.run(query.update(lns_is_read <- true)) > 0 {
                // Updated successfully
            } else {
                // Insert new
                try db.run(localNotificationStateTable.insert(
                    lns_thread_id <- threadId,
                    lns_is_read <- true,
                    lns_is_done <- false,
                    lns_is_snoozed <- false,
                    lns_is_pinned <- false
                ))
            }
        } catch {
            print("Failed to mark as read: \(error)")
        }
    }

    func markNotificationAsPinned(threadId: String, pinned: Bool) {
        guard let db = db else { return }
        do {
            // Update if exists, else insert
            let query = localNotificationStateTable.filter(lns_thread_id == threadId)
            if try db.run(query.update(lns_is_pinned <- pinned)) > 0 {
                // Updated successfully
            } else {
                // Insert new
                try db.run(localNotificationStateTable.insert(
                    lns_thread_id <- threadId,
                    lns_is_read <- false, // Default
                    lns_is_done <- false,
                    lns_is_snoozed <- false,
                    lns_is_pinned <- pinned
                ))
            }
        } catch {
            print("Failed to mark as pinned: \(error)")
        }
    }

    func getLocalState(threadId: String) -> (isDone: Bool, isSnoozed: Bool) {
        guard let db = db else { return (false, false) }
        do {
            let query = localNotificationStateTable.filter(lns_thread_id == threadId)
            if let row = try db.pluck(query) {
                return (row[lns_is_done], row[lns_is_snoozed])
            }
        } catch {
            print("Failed to get local state: \(error)")
        }
        return (false, false)
    }

    // MARK: - Issue/PR

    func upsertIssuePr(issue: GitHubResourceDetail, repoFullName: String, number: Int, type: String) {
        guard let db = db else { return }
        do {
            let assigneesJson = jsonString(issue.assignees)
            let authorJson = jsonString(issue.user)
            let labelsJson = jsonString(issue.labels)
            let mergedByJson = jsonString(issue.mergedBy)

            // If merged, save state as "merged" to persist that info, since schema doesn't have separate merged column
            let stateToSave = (issue.isMerged) ? "merged" : issue.state

            let insert = issuePrTable.insert(or: .replace,
                ip_id <- Int64(issue.id),
                ip_repo <- repoFullName,
                ip_number <- number,
                ip_type <- type,
                ip_state <- stateToSave,
                ip_title <- issue.title,
                ip_assignees <- assigneesJson,
                ip_author <- authorJson,
                ip_labels <- labelsJson,
                ip_comments <- issue.comments,
                ip_review_comments <- issue.reviewComments,
                ip_merged_by <- mergedByJson,
                ip_merged_at <- issue.mergedAt,
                ip_created_at <- issue.createdAt,
                ip_updated_at <- issue.updatedAt,
                ip_last_synced_at <- Date()
            )
            try db.run(insert)
        } catch {
            print("Failed to upsert issue/pr: \(error)")
        }
    }
    func getAllIssueDetails() -> [String: GitHubResourceDetail] {
        guard let db = db else { return [:] }
        var results: [String: GitHubResourceDetail] = [:]

        do {
            let rows = try db.prepare(issuePrTable)
            for row in rows {
                let repo = row[ip_repo]
                let number = row[ip_number]
                let type = row[ip_type]
                let state = row[ip_state]
                let title = row[ip_title]
                let updatedAt = row[ip_updated_at]
                let createdAt = row[ip_created_at]

                let user = try? JSONDecoder().decode(GitHubOwner.self, from: Data((row[ip_author] ?? "{}").utf8))
                let assignees = try? JSONDecoder().decode([GitHubOwner].self, from: Data((row[ip_assignees] ?? "[]").utf8))
                let labels = try? JSONDecoder().decode([GitHubLabel].self, from: Data((row[ip_labels] ?? "[]").utf8))
                let mergedBy = try? JSONDecoder().decode(GitHubOwner.self, from: Data((row[ip_merged_by] ?? "{}").utf8))
                let comments = row[ip_comments]
                let reviewComments = row[ip_review_comments]
                let mergedAt = row[ip_merged_at]

                let isMerged = (state == "merged")
                // Map "merged" back to "closed" for the struct, but set merged=true
                let structState = isMerged ? "closed" : state

                // Construct URL key to match what fetchNotifications uses (API URL)
                // GitHubNotification.subject.url is usually the API URL
                let urlType = (type == "PullRequest") ? "pulls" : "issues"
                let url = "https://api.github.com/repos/\(repo)/\(urlType)/\(number)"

                // Construct HTML URL
                let htmlUrlType = (type == "PullRequest") ? "pull" : "issues"
                let htmlUrl = "https://github.com/\(repo)/\(htmlUrlType)/\(number)"

                let detail = GitHubResourceDetail(
                    id: Int(row[ip_id]),
                    number: number,
                    title: title,
                    state: structState,
                    merged: isMerged,
                    body: nil,
                    bodyHtml: nil,
                    user: user ?? GitHubOwner(login: "unknown", avatarUrl: ""),
                    assignees: assignees,
                    labels: labels,
                    htmlUrl: htmlUrl,
                    comments: comments,
                    reviewComments: reviewComments,
                    updatedAt: updatedAt,
                    mergedBy: mergedBy,
                    mergedAt: mergedAt,
                    additions: nil,
                    deletions: nil,
                    createdAt: createdAt
                )

                results[url] = detail
            }
        } catch {
            print("Failed to fetch issue details: \(error)")
        }
        return results
    }

    // MARK: - Action Runs

    func upsertActionRun(_ run: GitHubWorkflowRun, repoFullName: String) {
        guard let db = db else { return }
        do {
            let insert = actionRunTable.insert(or: .replace,
                ar_id <- Int64(run.id),
                ar_repo <- repoFullName,
                ar_name <- run.name,
                ar_head_branch <- run.headBranch,
                ar_head_sha <- run.headSha,
                ar_status <- run.status,
                ar_conclusion <- run.conclusion,
                ar_created_at <- run.createdAt,
                ar_updated_at <- run.updatedAt,
                ar_html_url <- run.htmlUrl,
                ar_run_number <- run.runNumber,
                ar_event <- run.event
            )
            try db.run(insert)
        } catch {
            print("Failed to upsert action run: \(error)")
        }
    }

    func getLastActionRunSyncTime(repoFullName: String) -> Date? {
        guard let db = db else { return nil }
        do {
            let query = repoSyncStateTable.filter(rss_repo == repoFullName)
            if let row = try db.pluck(query) {
                return row[rss_last_run_sync]
            }
        } catch {
            print("Failed to get last action run sync time: \(error)")
        }
        return nil
    }

    func updateLastActionRunSyncTime(repoFullName: String, date: Date) {
        guard let db = db else { return }
        do {
            let insert = repoSyncStateTable.insert(or: .replace,
                rss_repo <- repoFullName,
                rss_last_run_sync <- date
            )
            try db.run(insert)
        } catch {
            print("Failed to update last action run sync time: \(error)")
        }
    }

    func getActionRuns(repoFullName: String, branch: String? = nil) -> [GitHubWorkflowRun] {
        guard let db = db else { return [] }
        var results: [GitHubWorkflowRun] = []

        do {
            var query = actionRunTable.filter(ar_repo == repoFullName)
            if let branch = branch {
                query = query.filter(ar_head_branch == branch)
            }
            query = query.order(ar_created_at.desc)
            let rows = try db.prepare(query)
            for row in rows {
                results.append(GitHubWorkflowRun(
                    id: Int(row[ar_id]),
                    name: row[ar_name],
                    headBranch: row[ar_head_branch],
                    headSha: row[ar_head_sha],
                    status: row[ar_status],
                    conclusion: row[ar_conclusion],
                    createdAt: row[ar_created_at],
                    updatedAt: row[ar_updated_at],
                    htmlUrl: row[ar_html_url],
                    runNumber: row[ar_run_number],
                    event: row[ar_event]
                ))
            }
        } catch {
            print("Failed to fetch action runs: \(error)")
        }
        return results
    }

    // Helper
    private func jsonString<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}