import SwiftUI

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Select a notification")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Choose a notification from the list to view details")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }
}

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
            } else {
                EmptyDetailView()
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