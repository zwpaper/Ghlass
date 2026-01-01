import SwiftUI
import MarkdownUI

struct NotificationDetailView: View {
    let notification: GitHubNotification
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title & Body Section (Grouped)
                if let url = notification.subject.url {
                    if let detail = viewModel.detailsCache[url] {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(notification.repository.fullName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    StateBadge(state: detail.state, isMerged: detail.isMerged, type: notification.subject.type)
                                }
                                
                                Text(notification.subject.title)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .textSelection(.enabled)
                            }
                            .padding(20)
                            .background(
                                Color.blue.opacity(0.02)
                            )
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
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
                                    
                                    Link(destination: URL(string: detail.htmlUrl)!) {
                                        HStack(spacing: 6) {
                                            Text("View on GitHub")
                                                .font(.caption)
                                            Image(systemName: "arrow.up.right")
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .glassEffect(cornerRadius: 8, material: .thin)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if let body = detail.body, !body.isEmpty {
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
                        .glassEffect(cornerRadius: 16, material: .regular)
                        
                        // Comments Section (Grouped)
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
                            .glassEffect(cornerRadius: 16, material: .regular)
                        } else if let comments = viewModel.commentsCache[url] {
                            if !comments.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    // Comments Header
                                    HStack {
                                        Image(systemName: "bubble.left.and.bubble.right.fill")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                        Text("Comments")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                        Text("(\(comments.count))")
                                            .font(.title3)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(20)
                                    .background(
                                        Color.purple.opacity(0.02)
                                    )
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                    
                                    // Comments List
                                    VStack(alignment: .leading, spacing: 12) {
                                        ForEach(comments) { comment in
                                            CommentView(comment: comment)
                                        }
                                    }
                                    .padding(16)
                                }
                                .glassEffect(cornerRadius: 16, material: .regular)
                            } else {
                                HStack {
                                    Image(systemName: "bubble.left")
                                        .foregroundColor(.secondary)
                                    Text("No comments yet")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(20)
                                .glassEffect(cornerRadius: 16, material: .regular)
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
                        .glassEffect(cornerRadius: 16, material: .regular)
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
                        .glassEffect(cornerRadius: 16, material: .regular)
                    } else {
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity)
                            .padding(50)
                            .glassEffect(cornerRadius: 16, material: .regular)
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
                    .glassEffect(cornerRadius: 16, material: .regular)
                }
            }
            .padding(24)
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
}
struct CommentView: View {
    let comment: GitHubComment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Comment Header
            HStack(spacing: 10) {
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
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.user.login)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Link to comment
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
            
            // Comment Body
            Divider()
                .background(Color.white.opacity(0.1))
            
            Markdown(comment.body)
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
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            ZStack {
                statusColor.opacity(0.15)
                LinearGradient(
                    colors: [
                        statusColor.opacity(0.2),
                        statusColor.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .foregroundColor(statusColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: statusColor.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    var statusText: String {
        if type == "PullRequest" && isMerged { return "Merged" }
        return state.capitalized
    }
    
    var statusIcon: String {
        if type == "PullRequest" && isMerged { return "arrow.triangle.merge" }
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