import SwiftUI

struct CheckSuiteDetailView: View {
    let detail: GitHubCheckSuiteDetail
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Info
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    if let app = detail.checkSuite.app {
                        AsyncImage(url: URL(string: app.owner.avatarUrl)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 2))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.headline)
                            Text(app.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                            .frame(width: 40, height: 40)
                            
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.headline)
                        }
                    }
                    Spacer()
                    
                    StatusBadge(status: detail.checkSuite.status, conclusion: detail.checkSuite.conclusion)
                }
                
                if let headBranch = detail.checkSuite.headBranch {
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption)
                        Text(headBranch)
                            .font(.caption.monospaced())
                        if let sha = detail.checkSuite.headSha {
                            Text(String(sha.prefix(7)))
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(20)
            .bubbleEffect(cornerRadius: 16)

            // Workflow Run Info (if matched)
            if let run = detail.workflowRun {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workflow Run")
                        .font(.headline)
                        .padding(.horizontal, 4)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(run.name)
                                .fontWeight(.medium)
                            HStack(spacing: 8) {
                                Label(run.event, systemImage: "bolt")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Label("#\(run.runNumber)", systemImage: "number")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if let url = URL(string: run.htmlUrl) {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Text("View Log")
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .bubbleEffect(cornerRadius: 12)
                }
            }

            // Check Runs List
            if !detail.checkRuns.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Check Runs")
                        .font(.headline)
                        .padding(.horizontal, 4)
                        
                    ForEach(detail.checkRuns) { run in
                        HStack(spacing: 12) {
                            StatusIcon(status: run.status, conclusion: run.conclusion)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(run.name)
                                    .fontWeight(.medium)
                                if let startedAt = run.startedAt {
                                    Text(startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if let htmlUrl = run.htmlUrl, let url = URL(string: htmlUrl) {
                                Link(destination: url) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .bubbleEffect(cornerRadius: 12)
                    }
                }
            }
        }
    }
}

struct StatusBadge: View {
    let status: String?
    let conclusion: String?
    
    var body: some View {
        HStack(spacing: 6) {
            StatusIcon(status: status, conclusion: conclusion)
            
            Text(statusText)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundColor(statusColor)
        .background(statusColor.opacity(0.1))
        .glassEffect(cornerRadius: 20, material: .ultraThinMaterial)
        .overlay(
            Capsule()
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    var statusText: String {
        if let conclusion = conclusion {
            return conclusion.capitalized
        }
        return status?.capitalized ?? "Unknown"
    }
    
    var statusColor: Color {
        switch conclusion {
        case "success": return .green
        case "failure", "timed_out", "cancelled": return .red
        case "neutral", "skipped": return .gray
        case "action_required": return .orange
        default:
            return status == "in_progress" ? .yellow : .secondary
        }
    }
}

struct StatusIcon: View {
    let status: String?
    let conclusion: String?
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
    }
    
    var iconName: String {
        switch conclusion {
        case "success": return "checkmark.circle.fill"
        case "failure": return "xmark.circle.fill"
        case "timed_out": return "clock.badge.exclamationmark.fill"
        case "cancelled": return "slash.circle.fill"
        case "skipped": return "arrow.turn.down.right"
        case "action_required": return "exclamationmark.circle.fill"
        case "neutral": return "minus.circle.fill"
        default:
            return status == "in_progress" ? "hourglass" : "circle"
        }
    }
    
    var iconColor: Color {
        switch conclusion {
        case "success": return .green
        case "failure", "timed_out", "cancelled": return .red
        case "neutral", "skipped": return .gray
        case "action_required": return .orange
        default:
            return status == "in_progress" ? .yellow : .secondary
        }
    }
}
