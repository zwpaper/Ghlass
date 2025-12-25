import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // When running as a SwiftPM executable (not an .app bundle), macOS may
        // default to a non-regular activation policy, which prevents windows
        // from appearing. Force the app to behave like a normal GUI app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct GhlassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()
    @State private var showSettings = false
    @State private var githubToken = GitHubService.shared.token ?? ""

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel, showSettings: $showSettings)
                .onAppear {
                    if GitHubService.shared.token == nil {
                        showSettings = true
                    } else {
                        Task {
                            await viewModel.fetchNotifications()
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView(githubToken: $githubToken)
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var showSettings: Bool

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationTitle("Ghlass")
        } content: {
            NotificationListView(viewModel: viewModel)
        } detail: {
            // In multi-select, if one item is selected (or the "primary" one), show it.
            // If multiple are selected, maybe show "X items selected" or just the last one.
            // For simplicity, we prioritize `selectedNotificationId` if set (single click),
            // or fallback to the first of `selectedNotificationIds`.

            if let selectedId = viewModel.selectedNotificationId ?? viewModel.selectedNotificationIds.first,
               let notification = viewModel.notifications.first(where: { $0.id == selectedId }) {
                NotificationDetailView(notification: notification, viewModel: viewModel)
                    .liquidBackground()
            } else {
                Text("Select a notification")
                    .font(.title)
                    .foregroundColor(.secondary)
                    .liquidBackground()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
}