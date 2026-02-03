import SwiftUI

struct CheckSuiteGroupDetailView: View {
    let title: String
    let notifications: [GitHubNotification]
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 0) {
                // Left: Icon & Count
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.2")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .font(.caption2)
                        Text("\(notifications.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospaced()
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(Capsule())
                }
                .padding(.leading, 8)

                Spacer()

                // Center: Repo & Title
                VStack(spacing: 4) {
                    if let first = notifications.first {
                        Text(first.repository.fullName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.05))
                .glassEffect(cornerRadius: 12, material: .ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

                Spacer()

                // Right: Archive Button
                Button(action: {
                    Task {
                        await viewModel.markAsDone(ids: notifications.map(\.id))
                    }
                }) {
                    Image(systemName: "archivebox")
                        .font(.caption)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .glassEffect(cornerRadius: 12, material: .ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Archive All")
                .padding(.trailing, 8)
            }
            .padding(12)
            .padding(.bottom, 8)

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
                iconView
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
                withAnimation {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                if let detail = viewModel.checkSuiteCache[notification.cacheKey] {
                    CheckSuiteDetailView(detail: detail, title: notification.subject.title, repoName: notification.repository.fullName, viewModel: viewModel)
                        .padding(.top, 12)
                        .transition(.opacity)
                } else if viewModel.loadingDetails.contains(notification.cacheKey) {
                    ProgressView()
                        .padding()
                        .frame(maxWidth: .infinity)
                } else {
                    Button("Load Details") {
                        Task {
                            await viewModel.fetchDetail(for: notification)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    @ViewBuilder
    var iconView: some View {
        if let detail = viewModel.checkSuiteCache[notification.cacheKey],
           let run = detail.workflowRun {

            switch run.conclusion {
            case "success":
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case "failure":
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case "neutral":
                Image(systemName: "minus.circle")
                    .foregroundColor(.gray)
            case "cancelled":
                Image(systemName: "slash.circle")
                    .foregroundColor(.gray)
            case "timed_out":
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
            case "action_required":
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
            default:
                if run.status == "in_progress" || run.status == "queued" {
                    Image(systemName: "hourglass")
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.secondary)
                }
            }
        } else {
             Image(systemName: "checkmark.shield") // Placeholder
                 .foregroundColor(.secondary)
        }
    }
}
