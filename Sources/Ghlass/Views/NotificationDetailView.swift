import SwiftUI
import MarkdownUI

enum TimelineItem: Identifiable {
    case comment(GitHubComment)
    case merged(by: GitHubOwner, at: Date)

    var id: String {
        switch self {
        case .comment(let c): return "comment-\(c.id)"
        case .merged(let user, let date): return "merged-\(user.login)-\(date.timeIntervalSince1970)"
        }
    }

    var date: Date {
        switch self {
        case .comment(let c): return c.createdAt
        case .merged(_, let date): return date
        }
    }
}

struct NotificationDetailView: View {
    let notification: GitHubNotification
    @ObservedObject var viewModel: AppViewModel
    @State private var webViewHeight: CGFloat = .zero

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Spacer for sticky header
                    Color.clear.frame(height: 60)

                    // Title & Body Section (Grouped)
                    if let url = notification.subject.url {
                        if let detail = viewModel.detailsCache[url] {
                            VStack(alignment: .leading, spacing: 0) {
                                // Author & Description
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(spacing: 12) {
                                        AsyncImage(url: URL(string: detail.user.avatarUrl)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Circle()
                                                .fill(LinearGradient(
                                                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ))
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                        )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(detail.user.login)
                                                .font(.headline)

                                            Text("opened this \(notification.subject.type.lowercased())")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()
                                    }

                                    if let bodyHtml = detail.bodyHtml, !bodyHtml.isEmpty {
                                        Divider()
                                            .background(Color.white.opacity(0.1))

                                        WebView(htmlContent: bodyHtml, dynamicHeight: $webViewHeight)
                                            .frame(height: webViewHeight > 0 ? webViewHeight : 100)
                                    } else if let body = detail.body, !body.isEmpty {
                                        Divider()
                                            .background(Color.white.opacity(0.1))

                                        Markdown(body)
                                            .textSelection(.enabled)
                                            .markdownTextStyle(\.text) {
                                                FontSize(14)
                                                ForegroundColor(.primary)
                                            }
                                    } else {
                                        Divider()
                                            .background(Color.white.opacity(0.1))

                                        Text("No description provided.")
                                            .font(.callout)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                }
                                .padding(20)
                            }
                            .bubbleEffect(cornerRadius: 16)

                            // Comments Section (Ungrouped)

                        if viewModel.loadingDetails.contains(url) {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading comments...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .bubbleEffect(cornerRadius: 16)
                        } else {
                            // Check if we have comments OR if it's merged (since merged event is a timeline item)
                            let timelineItems = getTimelineItems(url: url)

                            if !timelineItems.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    // Comments Header
                                    HStack {
                                        Image(systemName: "bubble.left.and.bubble.right.fill")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                        Text("Timeline")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                        Text("(\(timelineItems.count))")
                                            .font(.title3)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 4)

                                    // Timeline List
                                    LazyVStack(alignment: .leading, spacing: 16) {
                                        ForEach(timelineItems) { item in
                                            switch item {
                                            case .comment(let comment):
                                                CommentView(comment: comment)
                                            case .merged(let user, let date):
                                                MergedEventView(user: user, date: date)
                                            }
                                        }
                                    }
                                }
                            } else if viewModel.commentsCache[url] != nil { // Loaded but empty
                                HStack {
                                    Image(systemName: "bubble.left")
                                        .foregroundColor(.secondary)
                                    Text("No comments yet")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(20)
                                .bubbleEffect(cornerRadius: 16)
                            }
                        }
                    } else if viewModel.loadingDetails.contains(url) {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Loading details...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(50)
                        .bubbleEffect(cornerRadius: 16)
                    } else if let errorMessage = viewModel.failedDetails[url] {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.yellow)

                            Text("Failed to load details")
                                .font(.headline)

                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button(action: {
                                Task {
                                    await viewModel.fetchDetail(for: notification)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .glassEffect(cornerRadius: 10, material: .regular)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .bubbleEffect(cornerRadius: 16)
                    } else {
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity)
                            .padding(50)
                            .bubbleEffect(cornerRadius: 16)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No details available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(50)
                    .bubbleEffect(cornerRadius: 16)
                }
            }
            .padding(24)
        }

            // Sticky Header
            DetailHeaderView(notification: notification, detail: notification.subject.url.flatMap { viewModel.detailsCache[$0] }, viewModel: viewModel)
        }
        .background(
            ZStack {
                // Base layer
                Color(nsColor: .windowBackgroundColor)
                    .opacity(0.5)

                // Subtle grey gradient
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.03),
                        Color.gray.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
        .id(notification.id)
        .onAppear {
            Task {
                await viewModel.fetchDetail(for: notification)
            }
        }
    }
    func getTimelineItems(url: String) -> [TimelineItem] {
        var items: [TimelineItem] = []

        if let comments = viewModel.commentsCache[url] {
            items.append(contentsOf: comments.map { .comment($0) })
        }

        if let detail = viewModel.detailsCache[url], detail.isMerged, let mergedBy = detail.mergedBy, let mergedAt = detail.mergedAt {
            items.append(.merged(by: mergedBy, at: mergedAt))
        }

        return items.sorted { $0.date < $1.date }
    }
}

struct MergedEventView: View {
    let user: GitHubOwner
    let date: Date

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.clear, Color.purple.opacity(0.5), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                Image(systemName: "arrow.left.to.line.circle.fill")
                    .foregroundColor(.purple)

                AsyncImage(url: URL(string: user.avatarUrl)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 16, height: 16)
                .clipShape(Circle())

                Group {
                    Text("Merged by ")
                        .foregroundColor(.secondary)
                    + Text(user.login)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    + Text(" on \(date.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.1))
            .glassEffect(cornerRadius: 20, material: .thickMaterial)
            .overlay(
                Capsule()
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            )

            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.clear, Color.purple.opacity(0.5), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }
}

struct CommentView: View {
    let comment: GitHubComment
    @State private var webViewHeight: CGFloat = .zero

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar on the left
            AsyncImage(url: URL(string: comment.user.avatarUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.green.opacity(0.3), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
            )

            // Content on the right
            VStack(alignment: .leading, spacing: 14) {
                headerView

                if let diffHunk = comment.diffHunk {
                    diffView(diffHunk: diffHunk)
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                bodyView
            }
        }
        .padding(16)
        .bubbleEffect(cornerRadius: 16)
    }

    private var headerView: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(comment.user.login)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Link(destination: URL(string: comment.htmlUrl)!) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func diffView(diffHunk: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let path = comment.path {
                HStack {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(path)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))

                Divider()
                    .background(Color.white.opacity(0.1))
            }

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(diffHunk.components(separatedBy: .newlines).enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(diffLineColor(line))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)
                            .background(diffLineBackgroundColor(line))
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func diffLineColor(_ line: String) -> Color {
        if line.hasPrefix("+") { return .green }
        if line.hasPrefix("-") { return .red }
        if line.hasPrefix("@@") { return .purple }
        return .secondary
    }

    private func diffLineBackgroundColor(_ line: String) -> Color {
        if line.hasPrefix("+") { return Color.green.opacity(0.1) }
        if line.hasPrefix("-") { return Color.red.opacity(0.1) }
        if line.hasPrefix("@@") { return Color.purple.opacity(0.1) }
        return Color.clear
    }

    @ViewBuilder
    private var bodyView: some View {
        if let bodyHtml = comment.bodyHtml, !bodyHtml.isEmpty {
            WebView(htmlContent: bodyHtml, dynamicHeight: $webViewHeight)
                .frame(height: webViewHeight > 0 ? webViewHeight : 50)
        } else if let body = comment.body, !body.isEmpty {
            Markdown(body)
                .textSelection(.enabled)
                .markdownTextStyle(\.text) {
                    FontSize(13)
                    ForegroundColor(.primary)
                }
                .markdownTextStyle(\.code) {
                    FontFamilyVariant(.monospaced)
                    FontSize(12)
                    BackgroundColor(Color.white.opacity(0.05))
                }
        } else {
             Text("No content")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
    }
}

struct StateBadge: View {
    let state: String
    let isMerged: Bool
    let type: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.caption2)

            Text(statusText)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .foregroundColor(statusColor)
        .background(statusColor.opacity(0.1))
        .glassEffect(cornerRadius: 20, material: .ultraThinMaterial)
        .overlay(
            Capsule()
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }

    var statusText: String {
        if type == "PullRequest" && isMerged { return "Merged" }
        return state.capitalized
    }

    var statusIcon: String {
        if type == "PullRequest" && isMerged { return "arrow.left.to.line.circle" }
        if type == "PullRequest" && state == "closed" { return "shuffle.circle" }
        if type == "PullRequest" && state == "open" { return "arrow.left.to.line.circle" }

        switch state {
        case "open": return "circle"
        case "closed": return "checkmark.circle.fill"
        default: return "circle"
        }
    }

    var statusColor: Color {
        if type == "PullRequest" && isMerged { return .purple }
        switch state {
        case "open": return .green
        case "closed": return .red
        default: return .secondary
        }
    }
}

struct DetailHeaderView: View {
    let notification: GitHubNotification
    let detail: GitHubResourceDetail?
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Left: Status & Stats
            HStack(spacing: 12) {
                if let detail = detail {
                    StateBadge(state: detail.state, isMerged: detail.isMerged, type: notification.subject.type)

                    if let additions = detail.additions, let deletions = detail.deletions {                        HStack(spacing: 6) {
                            Text("+\(additions)").foregroundColor(.green)
                            Text("-\(deletions)").foregroundColor(.red)
                        }
                        .font(.caption.monospaced())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .bubbleEffect(cornerRadius: 20)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Middle: Repo & Title
            VStack(spacing: 2) {
                Text(notification.repository.fullName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Text(notification.subject.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .bubbleEffect(cornerRadius: 20)
            .frame(maxWidth: .infinity, alignment: .center)

            // Right: Actions
            HStack(spacing: 8) {
                Button(action: {
                    Task { await viewModel.markAsDone(ids: [notification.id]) }
                }) {
                    Image(systemName: "archivebox")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(10)
                        .bubbleEffect(cornerRadius: 20)
                }
                .buttonStyle(.plain)
                .help("Archive")

                if let detail = detail {
                    Link(destination: URL(string: detail.htmlUrl)!) {
                        Image(systemName: "arrow.up.right")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(10)
                            .bubbleEffect(cornerRadius: 20)
                    }
                    .buttonStyle(.plain)
                    .help("Open in GitHub")
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}