import SwiftUI
import AppKit

struct NotificationListView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showAddSheet = false
    @State private var newItemUrl = ""

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
                    if !viewModel.pinnedDisplayItems.isEmpty {
                        Section(header: Text("Pinned").font(.caption).foregroundColor(.secondary)) {
                            ForEach(viewModel.pinnedDisplayItems) { item in
                                notificationItem(item)
                            }
                        }
                    }
                    
                    Section(header: Text("Notifications").font(.caption).foregroundColor(.secondary)) {
                        ForEach(viewModel.unpinnedDisplayItems) { item in
                            notificationItem(item)
                        }
                    }
                }
                // When selection changes, mark as read and fetch details
                .onChange(of: viewModel.selectedNotificationId) { _, newId in
                    if let id = newId {
                        if id.hasPrefix("group|") {
                            // It's a group, fetch details for all notifications in the group
                            if let item = viewModel.displayItems.first(where: { $0.id == id }),
                               case .group(_, let notifications) = item {
                                for notification in notifications {
                                    Task {
                                        await viewModel.fetchDetail(for: notification)
                                    }
                                }
                            }
                        } else if let notification = viewModel.notifications.first(where: { $0.id == id }) {
                            // Mark as read immediately when selected
                            Task {
                                await viewModel.markAsRead(id: id)
                            }
                            // Fetch details and comments from GitHub API
                            Task {
                                await viewModel.fetchDetail(for: notification)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(
                    ZStack {
                        ListSelectionConfigurator()
                            .allowsHitTesting(false)

                        // Layered background
                        Color(nsColor: .windowBackgroundColor)
                            .opacity(0.4)

                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.04),
                                Color.blue.opacity(0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                )
                .frame(minWidth: 400)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.displayItems)

            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showAddSheet = true
                }) {
                    Label("Add Item", systemImage: "plus")
                }
            }

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
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            VStack(spacing: 20) {
                Text("Add Pinned Item")
                    .font(.headline)
                
                TextField("GitHub Issue or PR URL", text: $newItemUrl)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 300)
                
                HStack {
                    Button("Cancel") {
                        showAddSheet = false
                        newItemUrl = ""
                    }
                    
                    Button("Add") {
                        Task {
                            await viewModel.addPinnedItem(from: newItemUrl)
                            showAddSheet = false
                            newItemUrl = ""
                        }
                    }
                    .disabled(newItemUrl.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 350, height: 150)
        }
        .alert("Error", isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    @ViewBuilder
    func notificationItem(_ item: NotificationDisplayItem) -> some View {
        switch item {
        case .notification(let notification):
            NotificationRow(notification: notification, viewModel: viewModel)
                .tag(notification.id)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .padding(.vertical, 4)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9)),
                    removal: .opacity.combined(with: .scale(scale: 0.9))
                ))
                .onTapGesture {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        if viewModel.selectedNotificationIds.contains(notification.id) {
                            viewModel.selectedNotificationId = notification.id
                        } else {
                            viewModel.selectedNotificationId = notification.id
                        }
                    }
                }

        case .group(let title, let notifications):
            NotificationGroupRow(title: title, notifications: notifications, viewModel: viewModel)
                .tag(item.id)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .padding(.vertical, 4)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9)),
                    removal: .opacity.combined(with: .scale(scale: 0.9))
                ))
                .onTapGesture {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        viewModel.selectedNotificationId = item.id
                    }
                }
        }
    }
}

struct NotificationRow: View {
    let notification: GitHubNotification
    @ObservedObject var viewModel: AppViewModel

    var isSelected: Bool {
        viewModel.selectedNotificationId == notification.id
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Type Icon
            VStack(spacing: 6) {
                iconView
                    .font(.system(size: 20))
                    .frame(width: 30)

                if notification.unread {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.repository.fullName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(notification.subject.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                // Labels
                if let url = notification.subject.url, let detail = viewModel.detailsCache[url], let labels = detail.labels, !labels.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(labels) {
 label in
                                Text(label.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(label.colorObject)
                                    .foregroundColor(label.color.isLightColor() ? .black : .white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(height: 20)
                }

                HStack {
                    Spacer()

                    Text(notification.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Done/Archive Button & Comment Count
            VStack(spacing: 4) {
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

                Button(action: {
                    viewModel.togglePin(id: notification.id)
                }) {
                    Image(systemName: notification.isPinned ? "pin.fill" : "pin")
                        .foregroundColor(notification.isPinned ? .orange : .secondary)
                        .padding(4)
                        .rotationEffect(.degrees(notification.isPinned ? 45 : 0))
                }
                .buttonStyle(PlainButtonStyle())
                .help(notification.isPinned ? "Unpin" : "Pin")

                if let url = notification.subject.url,
                   let detail = viewModel.detailsCache[url] {
                    let totalComments = detail.comments + (detail.reviewComments ?? 0)
                    if totalComments > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 10))
                            Text("\(totalComments)")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .glassEffect(cornerRadius: 12, material: .thickMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
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
                    Image(systemName: "arrow.left.to.line.circle")
                        .foregroundColor(.purple)
                } else if detail.state == "closed" {
                    Image(systemName: "shuffle.circle")
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "arrow.left.to.line.circle")
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
                Image(systemName: "arrow.left.to.line.circle")
                    .foregroundColor(.blue)
            case "Release":
                Image(systemName: "tag")
                    .foregroundColor(.orange)
            case "Discussion":
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundColor(.blue)
            case "Commit":
                Image(systemName: "slider.vertical.3")
                    .foregroundColor(.gray)
            default:
                Image(systemName: "bell")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct NotificationGroupRow: View {
    let title: String
    let notifications: [GitHubNotification]
    @ObservedObject var viewModel: AppViewModel
    
    var isSelected: Bool {
        let repo = notifications.first?.repository.fullName ?? ""
        let isPinned = notifications.first?.isPinned ?? false
        let groupId = "group|\(repo)|\(title)|\(isPinned ? "pinned" : "unpinned")"
        return viewModel.selectedNotificationId == groupId
    }
    
    var isPinned: Bool {
        // If any is pinned, we consider the group pinned for display purposes?
        // Or if all are pinned?
        // Based on AppViewModel logic, if we pin a group, we pin all.
        // So checking the first one or all should be consistent.
        // But for display, if we have mixed state (pinned/unpinned split),
        // the group in "Pinned" section will have all pinned items.
        // The group in "Unpinned" section will have all unpinned items.
        // So checking the first one is sufficient as they are grouped by pin status first.
        notifications.first?.isPinned ?? false
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            VStack(spacing: 6) {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 20))
                    .frame(width: 30)
                    .foregroundColor(.secondary)

                // Unread dot if any in group is unread
                if notifications.contains(where: { $0.unread }) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let first = notifications.first {
                    Text(first.repository.fullName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text("\(notifications.count) notifications")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                HStack {
                    Spacer()
                    if let maxDate = notifications.map(\.updatedAt).max() {
                        Text(maxDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Archive Button
            VStack(spacing: 4) {
                Button(action: {
                    Task {
                        await viewModel.markAsDone(ids: notifications.map(\.id))
                    }
                }) {
                    Image(systemName: "archivebox")
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Archive All")
                
                Button(action: {
                    let repo = notifications.first?.repository.fullName ?? ""
                    let isPinned = notifications.first?.isPinned ?? false
                    let groupId = "group|\(repo)|\(title)|\(isPinned ? "pinned" : "unpinned")"
                    viewModel.togglePin(id: groupId)
                }) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .foregroundColor(isPinned ? .orange : .secondary)
                        .padding(4)
                        .rotationEffect(.degrees(isPinned ? 45 : 0))
                }
                .buttonStyle(PlainButtonStyle())
                .help(isPinned ? "Unpin Group" : "Pin Group")
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .glassEffect(cornerRadius: 12, material: .thickMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
}

private struct ListSelectionConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.isHidden = true
        DispatchQueue.main.async {
            Self.configureTableView(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.configureTableView(from: nsView)
        }
    }

    private static func configureTableView(from view: NSView) {
        guard let tableView = locateTableView(startingFrom: view) else { return }
        tableView.selectionHighlightStyle = .none
        tableView.backgroundColor = .clear
    }

    private static func locateTableView(startingFrom view: NSView) -> NSTableView? {
        var visited = Set<ObjectIdentifier>()
        var queue: [NSView] = [view]
        while !queue.isEmpty {
            let candidate = queue.removeFirst()
            let identifier = ObjectIdentifier(candidate)
            if visited.contains(identifier) { continue }
            visited.insert(identifier)
            if let tableView = candidate as? NSTableView {
                return tableView
            }
            queue.append(contentsOf: candidate.subviews)
            if let superview = candidate.superview {
                queue.append(superview)
            }
        }
        return nil
    }
}