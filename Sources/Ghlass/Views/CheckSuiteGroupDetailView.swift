import SwiftUI

struct CheckSuiteGroupDetailView: View {
    let title: String
    let notifications: [GitHubNotification]
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "gearshape.2")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                if let first = notifications.first {
                    Text(first.repository.fullName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("\(notifications.count) notifications")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Archive All") {
                        Task {
                            await viewModel.markAsDone(ids: notifications.map(\.id))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(notifications.sorted(by: { $0.updatedAt > $1.updatedAt })) { notification in
                        CheckSuiteNotificationRow(notification: notification, viewModel: viewModel)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        
                        Divider()
                            .padding(.leading, 20)
                    }
                }
                .padding(.vertical)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct CheckSuiteNotificationRow: View {
    let notification: GitHubNotification
    @ObservedObject var viewModel: AppViewModel
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Image(systemName: "checkmark.shield") // Placeholder, ideally fetch status
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.subject.title)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text(notification.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack {
                    Button(action: {
                        Task {
                            await viewModel.markAsDone(ids: [notification.id])
                        }
                    }) {
                        Image(systemName: "archivebox")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Archive")
                    
                    if let urlString = notification.subject.url, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Open in Browser")
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Potential expansion logic here if we want to show details inline
            }
        }
    }
}
