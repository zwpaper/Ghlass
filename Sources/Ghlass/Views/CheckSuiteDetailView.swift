import SwiftUI

struct CheckSuiteDetailView: View {
    let detail: GitHubCheckSuiteDetail
    let title: String
    let repoName: String?
    @ObservedObject var viewModel: AppViewModel
    
    init(detail: GitHubCheckSuiteDetail, title: String, repoName: String? = nil, viewModel: AppViewModel) {
        self.detail = detail
        self.title = title
        self.repoName = repoName
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let run = detail.workflowRun {
                // Header Info using run details
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.shield")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                            .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            if let repoName = repoName {
                                Text(repoName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(run.name)
                                .font(.headline)
                            Text(title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()

                        StatusBadge(status: run.status, conclusion: run.conclusion)
                    }

                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption)
                        Text(run.headBranch)
                            .font(.caption.monospaced())

                        Text(String(run.headSha.prefix(7)))
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)

                    // Additional Run Info
                     HStack(spacing: 12) {
                        Label(run.event, systemImage: "bolt")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("#\(run.runNumber)", systemImage: "number")
                            .font(.caption)
                            .foregroundColor(.secondary)

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
                }
                .padding(20)
                .bubbleEffect(cornerRadius: 16)
                
                // Jobs Section
                if let jobs = viewModel.jobsCache[run.id] {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Jobs")
                                .font(.headline)
                            Spacer()
                            Text("\(jobs.count) jobs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 4)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(jobs) { job in
                                JobView(job: job)
                            }
                        }
                    }
                } else {
                    // Loading state
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading jobs...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .bubbleEffect(cornerRadius: 16)
                }

            } else {
                // Fallback if no run matched
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Workflow run details not found")
                        .font(.headline)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .bubbleEffect(cornerRadius: 16)
            }
        }
    }
}

struct JobView: View {
    let job: GitHubJob
    @State private var isExpanded = false
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Job Header
            HStack(spacing: 12) {
                StatusIcon(status: job.status, conclusion: job.conclusion)
                    .font(.system(size: 18))
                
                Text(job.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if let completedAt = job.completedAt, let startedAt = job.startedAt {
                    Text(durationString(start: startedAt, end: completedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .rotationEffect(Angle(degrees: isExpanded ? 90 : 0))
            }
            .padding(16)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
            
            // Steps
            if isExpanded, let steps = job.steps {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        StepRow(step: step, isLast: index == steps.count - 1)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 20)
                .background(Color.black.opacity(0.1))
            }
        }
        .background(
            ZStack {
                if isExpanded {
                    Color.accentColor.opacity(0.05)
                } else if isHovering {
                    Color.white.opacity(0.15)
                } else {
                    Color.white.opacity(0.1)
                }
            }
        )
        .glassEffect(cornerRadius: 16, material: .ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isExpanded ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    func durationString(start: Date, end: Date) -> String {
        let diff = end.timeIntervalSince(start)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: diff) ?? ""
    }
}

struct StepRow: View {
    let step: GitHubStep
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline
            VStack(spacing: 0) {
                StatusIcon(status: step.status, conclusion: step.conclusion)
                    .font(.system(size: 12))
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                    )
                
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 18)
            
            // Content
            HStack {
                Text(step.name)
                    .font(.subheadline)
                    .foregroundColor(step.conclusion == "failure" ? .red : .primary)
                
                Spacer()
                
                if let completedAt = step.completedAt, let startedAt = step.startedAt {
                    let diff = completedAt.timeIntervalSince(startedAt)
                    if diff > 0 {
                        Text(String(format: "%.1fs", diff))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.bottom, isLast ? 0 : 12)
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
