import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Ghlass")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    // Unread Filter
                    Toggle("Unread Only", isOn: $viewModel.showUnreadOnly)
                        .padding(.horizontal)
                    
                    // Open Only Filter
                    Toggle("Open Only", isOn: $viewModel.showOpenOnly)
                        .padding(.horizontal)
                        .help("Only show notifications for Open issues/PRs (requires details loaded)")
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    // Repositories Filter
                    DisclosureGroup("Repositories", isExpanded: .constant(true)) {
                        ForEach(viewModel.availableRepos, id: \.self) {
 repo in
                            HStack {
                                Image(systemName: viewModel.selectedRepos.contains(repo) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(viewModel.selectedRepos.contains(repo) ? .blue : .secondary)
                                Text(repo)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(viewModel.countForRepo(repo))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleRepoFilter(repo)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    // Types Filter
                    DisclosureGroup("Types", isExpanded: .constant(true)) {
                        ForEach(viewModel.availableTypes, id: \.self) {
 type in
                            HStack {
                                Image(systemName: viewModel.selectedTypes.contains(type) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(viewModel.selectedTypes.contains(type) ? .blue : .secondary)
                                Text(type)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(viewModel.countForType(type))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleTypeFilter(type)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .frame(width: 250)
        .background(
            ZStack {
                // Base layer
                Color(nsColor: .windowBackgroundColor)
                    .opacity(0.3)
                
                // Gradient overlay
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.05),
                        Color.purple.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
    }
}