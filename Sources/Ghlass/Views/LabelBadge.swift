import SwiftUI

struct LabelBadge: View {
    let label: GitHubLabel
    
    var body: some View {
        let isLight = label.color.isLightColor()
        
        Text(label.name)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: label.color))
            .foregroundColor(isLight ? .black : .white)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
    }
}
