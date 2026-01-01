import Foundation

struct GitHubNotification: Identifiable, Codable, Hashable {
    let id: String
    let repository: GitHubRepository
    let subject: NotificationSubject
    let reason: String
    let unread: Bool
    let updatedAt: Date
    let url: String
    
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
            url: url
        )
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
    let user: GitHubOwner
    let assignees: [GitHubOwner]?
    let htmlUrl: String
    let comments: Int
    let updatedAt: Date
    
    var isMerged: Bool { merged == true }
    
    enum CodingKeys: String, CodingKey {
        case id
        case number
        case title
        case state
        case merged
        case body
        case user
        case assignees
        case htmlUrl = "html_url"
        case comments
        case updatedAt = "updated_at"
    }
}

struct GitHubComment: Codable, Hashable, Identifiable {
    let id: Int
    let body: String
    let user: GitHubOwner
    let createdAt: Date
    let htmlUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case body
        case user
        case createdAt = "created_at"
        case htmlUrl = "html_url"
    }
}