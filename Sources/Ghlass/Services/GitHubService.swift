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

    enum ServiceError: LocalizedError {
        case noToken
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case apiError(statusCode: Int)
        case decodingFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .noToken: return "No GitHub token found"
            case .invalidURL: return "Invalid URL"
            case .requestFailed(let error): return "Request failed: \(error.localizedDescription)"
            case .invalidResponse: return "Invalid response from server"
            case .apiError(let statusCode): return "GitHub API Error: \(statusCode)"
            case .decodingFailed(let error): return "Decoding failed: \(error.localizedDescription)"
            }
        }
    }

    func fetchNotifications(since: Date? = nil) async throws -> [GitHubNotification] {
        guard let token = token, !token.isEmpty else {
            throw ServiceError.noToken
        }

        var urlString = "https://api.github.com/notifications?all=true"
        if let since = since {
            let formatter = ISO8601DateFormatter()
            urlString += "&since=\(formatter.string(from: since))"
        }

        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("Fetching notifications status: \(httpResponse.statusCode)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ServiceError.apiError(statusCode: httpResponse.statusCode)
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

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 204 else {
            throw ServiceError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    func markAsRead(notificationId: String) async throws {
        guard let token = token, !token.isEmpty else {
            throw ServiceError.noToken
        }

        guard let url = URL(string: "https://api.github.com/notifications/threads/\(notificationId)") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 205 else {
            throw ServiceError.apiError(statusCode: httpResponse.statusCode)
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

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            print("Request failed for \(url). Status: \(httpResponse.statusCode)")
            if let body = String(data: data, encoding: .utf8) {
                print("Response body: \(body)")
            }
            throw ServiceError.apiError(statusCode: httpResponse.statusCode)
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

        guard let url = URL(string: commentsUrl) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ServiceError.apiError(statusCode: httpResponse.statusCode)
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