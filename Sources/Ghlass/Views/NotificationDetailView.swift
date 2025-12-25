import SwiftUI
import MarkdownUI

struct NotificationDetailView: View {
    let notification: GitHubNotification
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.repository.fullName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(notification.subject.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    if let url = notification.subject.url, let detail = viewModel.detailsCache[url] {
                        StateBadge(state: detail.state, isMerged: detail.isMerged, type: notification.subject.type)
                    }
                }
                
                Divider()
                
                // Body
                if let url = notification.subject.url {
                    if let detail = viewModel.detailsCache[url] {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                AsyncImage(url: URL(string: detail.user.avatarUrl)) {
                                    image in
                                    image.resizable()
                                } placeholder: {
                                    Circle().fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                
                                Text(detail.user.login)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Link(destination: URL(string: detail.htmlUrl)!) {
                                    Image(systemName: "arrow.up.right.square")
                                }
                            }
                            
                            Markdown(detail.body ?? "No description provided.")
                                .textSelection(.enabled)
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                        }
                        
                        // Comments
                        if let comments = viewModel.commentsCache[url], !comments.isEmpty {
                            Divider()
                                .padding(.vertical)
                            
                            Text("Comments")
                                .font(.headline)
                            
                            ForEach(comments) {
 comment in
                                CommentView(comment: comment)
                            }
                        }
                    } else if viewModel.loadingDetails.contains(url) {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 50)
                    } else {
                        Text("Select to load details")
                            .onAppear {
                                Task {
                                    await viewModel.fetchDetail(for: notification)
                                }
                            }
                    }
                }
            }
            .padding()
        }
    }
}

struct CommentView: View {
    let comment: GitHubComment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AsyncImage(url: URL(string: comment.user.avatarUrl)) {
                    image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                
                Text(comment.user.login)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Markdown(comment.body)
                .textSelection(.enabled)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct StateBadge: View {
    let state: String
    let isMerged: Bool
    let type: String
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(statusColor.opacity(0.4), lineWidth: 1)
            )
    }
    
    var statusText: String {
        if type == "PullRequest" && isMerged { return "Merged" }
        return state.capitalized
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