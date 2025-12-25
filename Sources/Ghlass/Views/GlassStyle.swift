import SwiftUI

struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var material: Material = .ultraThinMaterial
    var shadowRadius: CGFloat = 5
    
    func body(content: Content) -> some View {
        content
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

extension View {
    func glassEffect(cornerRadius: CGFloat = 16, material: Material = .ultraThinMaterial) -> some View {
        self.modifier(GlassModifier(cornerRadius: cornerRadius, material: material))
    }
    
    func liquidBackground() -> some View {
        self.background(
            ZStack {
                Color.clear // Fallback/Base
                VisualEffectView(material: .headerView, blendingMode: .behindWindow)
                    .ignoresSafeArea()
            }
        )
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}