import SwiftUI

struct NotificationListView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.notifications.isEmpty {
                ProgressView("Loading notifications...")
            } else if viewModel.filteredNotifications.isEmpty {
                VStack {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No notifications found")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            } else {
                List(selection: $viewModel.selectedNotificationIds) {
                    ForEach(viewModel.filteredNotifications) {
 notification in
                        NotificationRow(notification: notification, viewModel: viewModel)
                            .tag(notification.id)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
                .frame(minWidth: 400)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task {
                        await viewModel.markSelectedAsDone()
                    }
                }) {
                    Label("Archive Selected", systemImage: "archivebox")
                }
                .disabled(viewModel.selectedNotificationIds.isEmpty)
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    Task {
                        await viewModel.fetchNotifications()
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

struct NotificationRow: View {
    let notification: GitHubNotification
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Type Icon
            iconView
                .font(.system(size: 20))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.repository.fullName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(notification.subject.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack {
                    Text(notification.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if notification.unread {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            
            // Done/Archive Button
            Button(action: {
                Task {
                    await viewModel.markAsDone(ids: [notification.id])
                }
            }) {
                Image(systemName: "archivebox")
                    .foregroundColor(.secondary)
                    .padding(4)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Mark as done (Archive)")
        }
        .padding()
        .glassEffect(cornerRadius: 12, material: .thinMaterial)
        .onAppear {
            // Optional: Prefetch details here if desired
        }
    }
    
    @ViewBuilder
    var iconView: some View {
        if let url = notification.subject.url, let detail = viewModel.detailsCache[url] {
            // We have details, show state-specific icon
            if notification.subject.type == "PullRequest" {
                if detail.isMerged {
                    Image(systemName: "arrow.triangle.merge")
                        .foregroundColor(.purple)
                } else if detail.state == "closed" {
                    Image(systemName: "arrow.triangle.pull")
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.green)
                }
            } else if notification.subject.type == "Issue" {
                if detail.state == "closed" {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.purple)
                } else {
                    Image(systemName: "dot.circle")
                        .foregroundColor(.green)
                }
            } else {
                // Fallback for other types with details
                fallbackIcon
            }
        } else {
            // No details yet, show generic type icon
            fallbackIcon
        }
    }
    
    var fallbackIcon: some View {
        Group {
            switch notification.subject.type {
            case "Issue":
                Image(systemName: "dot.circle")
                    .foregroundColor(.green)
            case "PullRequest":
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.blue)
            case "Release":
                Image(systemName: "tag")
                    .foregroundColor(.orange)
            case "Discussion":
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundColor(.blue)
            case "Commit":
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.gray)
            default:
                Image(systemName: "bell")
                    .foregroundColor(.secondary)
            }
        }
    }
}