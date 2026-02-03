import Foundation

struct GitHubNotification: Identifiable, Codable, Hashable {
    let id: String
    let repository: GitHubRepository
    let subject: NotificationSubject
    let reason: String
    let unread: Bool
    let updatedAt: Date
    let url: String
    var isDone: Bool = false

    // Helper to get the ID of the subject from its URL
    var subjectId: String? {
        subject.url?.components(separatedBy: "/").last
    }

    enum CodingKeys: String, CodingKey {
        case id
        case repository
        case subject
        case reason
        case unread
        case updatedAt = "updated_at"
        case url
    }

    func markedAsRead() -> GitHubNotification {
        return GitHubNotification(
            id: id,
            repository: repository,
            subject: subject,
            reason: reason,
            unread: false,
            updatedAt: updatedAt,
            url: url,
            isDone: isDone
        )
    }
    
    var cacheKey: String {
        if subject.type == "CheckSuite" {
            return subject.url ?? "checksuite:\(id)"
        }
        return subject.url ?? ""
    }
}

struct GitHubRepository: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let owner: GitHubOwner

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case owner
    }
}

struct GitHubOwner: Codable, Hashable {
    let login: String
    let avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

struct GitHubLabel: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let color: String
    let description: String?
}

struct NotificationSubject: Codable, Hashable {
    let title: String
    let type: String
    let url: String?
    // Note: Notification API doesn't return state directly, we must fetch details
}

// For filtering
enum NotificationReason: String, CaseIterable, Identifiable {
    case assign
    case author
    case comment
    case invitation
    case manual
    case mention
    case reviewRequested = "review_requested"
    case securityAlert = "security_alert"
    case stateChange = "state_change"
    case subscribed
    case teamMention = "team_mention"
    case ciActivity = "ci_activity"
    case other // fallback

    var id: String { self.rawValue }
}

// MARK: - Detailed Models

struct GitHubResourceDetail: Codable, Hashable {
    let id: Int
    let number: Int
    let title: String
    let state: String // "open", "closed"
    let merged: Bool? // Only for PRs
    let body: String?
    let bodyHtml: String?
    let user: GitHubOwner
    let assignees: [GitHubOwner]?
    let labels: [GitHubLabel]?
    let htmlUrl: String
    let comments: Int
    let reviewComments: Int?
    let updatedAt: Date
    let mergedBy: GitHubOwner?
    let mergedAt: Date?
    let additions: Int?
    let deletions: Int?
    let createdAt: Date?

    var isMerged: Bool { merged == true }

    enum CodingKeys: String, CodingKey {
        case id
        case number
        case title
        case state
        case merged
        case body
        case bodyHtml = "body_html"
        case user
        case assignees
        case labels
        case htmlUrl = "html_url"
        case comments
        case reviewComments = "review_comments"
        case updatedAt = "updated_at"
        case mergedBy = "merged_by"
        case mergedAt = "merged_at"
        case additions
        case deletions
        case createdAt = "created_at"
    }
}

struct GitHubComment: Codable, Hashable, Identifiable {
    let id: Int
    let body: String?
    let bodyHtml: String?
    let user: GitHubOwner
    let createdAt: Date
    let htmlUrl: String
    let diffHunk: String?
    let path: String?

    enum CodingKeys: String, CodingKey {
        case id
        case body
        case bodyHtml = "body_html"
        case user
        case createdAt = "created_at"
        case htmlUrl = "html_url"
        case diffHunk = "diff_hunk"
        case path
    }
}

struct GitHubCheckSuite: Codable, Hashable, Identifiable {
    let id: Int
    let status: String?
    let conclusion: String?
    let headBranch: String?
    let headSha: String?
    let checkRunsUrl: String
    let app: GitHubApp?
    let repository: GitHubRepository
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case conclusion
        case headBranch = "head_branch"
        case headSha = "head_sha"
        case checkRunsUrl = "check_runs_url"
        case app
        case repository
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GitHubCheckRun: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let status: String?
    let conclusion: String?
    let startedAt: Date?
    let completedAt: Date?
    let htmlUrl: String?
    let detailsUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case conclusion
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case htmlUrl = "html_url"
        case detailsUrl = "details_url"
    }
}

struct GitHubApp: Codable, Hashable, Identifiable {
    let id: Int
    let slug: String?
    let name: String
    let owner: GitHubOwner
}

struct GitHubCheckSuiteDetail: Hashable {
    var workflowRun: GitHubWorkflowRun?
}

struct GitHubWorkflowRun: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let headBranch: String
    let headSha: String
    let status: String?
    let conclusion: String?
    let createdAt: Date
    let updatedAt: Date
    let htmlUrl: String
    let runNumber: Int
    let event: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case headBranch = "head_branch"
        case headSha = "head_sha"
        case status
        case conclusion
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
        case runNumber = "run_number"
        case event
    }
}

struct GitHubWorkflowRunsResponse: Decodable {
    let total_count: Int
    let workflow_runs: [GitHubWorkflowRun]
}

struct GitHubJob: Codable, Hashable, Identifiable {
    let id: Int
    let runId: Int
    let name: String
    let status: String? // "queued", "in_progress", "completed"
    let conclusion: String? // "success", "failure", "neutral", "cancelled", "skipped", "timed_out", "action_required"
    let startedAt: Date?
    let completedAt: Date?
    let htmlUrl: String?
    let steps: [GitHubStep]?

    enum CodingKeys: String, CodingKey {
        case id
        case runId = "run_id"
        case name
        case status
        case conclusion
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case htmlUrl = "html_url"
        case steps
    }
}

struct GitHubStep: Codable, Hashable, Identifiable {
    // Steps don't always have IDs in the API response, so we might need a computed ID or use number
    // Actually the API docs say steps have "number".
    // Let's make it Identifiable by combining name and number if needed, or just use UUID if not provided.
    // The API response example doesn't show an ID for steps, just number.
    
    let name: String
    let status: String?
    let conclusion: String?
    let number: Int
    let startedAt: Date?
    let completedAt: Date?

    var id: String { "\(number)-\(name)" }

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case conclusion
        case number
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

struct GitHubJobsResponse: Decodable {
    let total_count: Int
    let jobs: [GitHubJob]
}

struct GitHubRelease: Codable, Hashable, Identifiable {
    let id: Int
    let tagName: String
    let targetCommitish: String
    let name: String?
    let body: String?
    let bodyHtml: String?
    let draft: Bool
    let prerelease: Bool
    let createdAt: Date
    let publishedAt: Date?
    let author: GitHubOwner
    let assets: [GitHubAsset]
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case targetCommitish = "target_commitish"
        case name
        case body
        case bodyHtml = "body_html"
        case draft
        case prerelease
        case createdAt = "created_at"
        case publishedAt = "published_at"
        case author
        case assets
        case htmlUrl = "html_url"
    }
}

struct GitHubAsset: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let label: String?
    let contentType: String
    let state: String
    let size: Int
    let downloadCount: Int
    let createdAt: Date
    let updatedAt: Date
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case label
        case contentType = "content_type"
        case state
        case size
        case downloadCount = "download_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case browserDownloadUrl = "browser_download_url"
    }
}
