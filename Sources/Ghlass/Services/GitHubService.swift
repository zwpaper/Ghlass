import Foundation

class GitHubService {
    static let shared = GitHubService()

    private let session = URLSession.shared
    private let defaults = UserDefaults.standard
    private let tokenKey = "github_pat"

    var token: String? {
        get { defaults.string(forKey: tokenKey) }
        set { defaults.set(newValue, forKey: tokenKey) }
    }

    enum ServiceError: Error {
        case noToken
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case decodingFailed(Error)
    }

    func fetchNotifications() async throws -> [GitHubNotification] {
        guard let token = token, !token.isEmpty else {
            throw ServiceError.noToken
        }

        guard let url = URL(string: "https://api.github.com/notifications?all=true") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("Fetching notifications status: \(httpResponse.statusCode)")
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServiceError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([GitHubNotification].self, from: data)
        } catch {
            throw ServiceError.decodingFailed(error)
        }
    }

    func markAsDone(notificationId: String) async throws {
        guard let token = token, !token.isEmpty else {
            throw ServiceError.noToken
        }

        guard let url = URL(string: "https://api.github.com/notifications/threads/\(notificationId)") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (_, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("Marking notification \(notificationId) as done. Status code: \(httpResponse.statusCode)")
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
            // 204 No Content is the expected response for success
            throw ServiceError.invalidResponse
        }
    }

    func fetchResourceDetail(url: String) async throws -> GitHubResourceDetail {
        guard let token = token, !token.isEmpty else {
            throw ServiceError.noToken
        }

        // The notification subject URL for Pull Requests points to the "pulls" API endpoint,
        // which is correct. However, sometimes the notification API returns a URL that might
        // need adjustment or specific handling if it points to html_url instead of api_url.
        // But usually subject.url is the API URL.
        //
        // One common issue is that the notification subject URL for a PR might be:
        // https://api.github.com/repos/owner/repo/pulls/123
        //
        // If we get a 404, it might be an issue with the token scope or the URL itself.
        // However, for "PullRequest" type, the URL should be correct.
        //
        // Let's ensure we are using the URL string provided directly.

        guard let urlObj = URL(string: url) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: urlObj)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServiceError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(GitHubResourceDetail.self, from: data)
        } catch {
            throw ServiceError.decodingFailed(error)
        }
    }

    func fetchComments(commentsUrl: String) async throws -> [GitHubComment] {
        guard let token = token, !token.isEmpty else {
            throw ServiceError.noToken
        }

        // The comments URL might be part of the resource detail or constructed
        // Usually issues/PRs have a "comments_url" field, but for now we might construct it or use what we have
        // If the passed URL is the issue URL, we append /comments
        // However, the correct way is usually to get it from the detail.
        // For simplicity, let's assume we pass the full comments URL or handle the logic elsewhere.
        // Actually, let's assume the caller passes the correct API URL for comments.

        guard let url = URL(string: commentsUrl) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServiceError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([GitHubComment].self, from: data)
        } catch {
            throw ServiceError.decodingFailed(error)
        }
    }
}