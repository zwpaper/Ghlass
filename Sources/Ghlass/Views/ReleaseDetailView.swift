import SwiftUI
import MarkdownUI

struct ReleaseDetailView: View {
    let release: GitHubRelease
    @Binding var webViewHeight: CGFloat
    @Binding var isWebViewLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    AsyncImage(url: URL(string: release.author.avatarUrl)) { image in
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
                        Text(release.author.login)
                            .font(.headline)

                        Text("released this \(release.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                    
                    if release.prerelease {
                        Text("Pre-release")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                    
                    if release.draft {
                        Text("Draft")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.secondary)
                            .clipShape(Capsule())
                    }
                }
                
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.blue)
                    Text(release.tagName)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    if let name = release.name, !name.isEmpty, name != release.tagName {
                        Text("-")
                            .foregroundColor(.secondary)
                        Text(name)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)

            Divider()
                .background(Color.white.opacity(0.1))

            // Body
            VStack(alignment: .leading, spacing: 16) {
                if let bodyHtml = release.bodyHtml, !bodyHtml.isEmpty {
                    ZStack {
                        WebView(htmlContent: bodyHtml, dynamicHeight: $webViewHeight, isLoading: $isWebViewLoading)
                            .frame(height: webViewHeight > 0 ? webViewHeight : 100)
                            .opacity(isWebViewLoading ? 0 : 1)

                        if isWebViewLoading {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(0..<3) { _ in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 14)
                                        .frame(maxWidth: .infinity)
                                }
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 200, height: 14)
                            }
                            .shimmer()
                        }
                    }
                } else if let body = release.body, !body.isEmpty {
                    Markdown(body)
                        .textSelection(.enabled)
                        .markdownTextStyle(\.text) {
                            FontSize(14)
                            ForegroundColor(.primary)
                        }
                } else {
                    Text("No description provided.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding(20)
            
            // Assets
            if !release.assets.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Assets")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    ForEach(release.assets) { asset in
                        Button(action: {
                            if let url = URL(string: asset.browserDownloadUrl) {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "cube.box.fill")
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(asset.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 8) {
                                        Text(formatBytes(asset.size))
                                        Text("•")
                                        Text("\(asset.downloadCount) downloads")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.down.circle")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { isHovered in
                            if isHovered {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .bubbleEffect(cornerRadius: 16)
    }
    
    func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
