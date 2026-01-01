import SwiftUI

struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var material: Material = .ultraThinMaterial
    var shadowRadius: CGFloat = 5
    var borderOpacity: Double = 0.2
    
    func body(content: Content) -> some View {
        content
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.05), radius: shadowRadius, x: 0, y: 2)
            .shadow(color: Color.white.opacity(0.1), radius: 1, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(borderOpacity),
                                Color.white.opacity(borderOpacity * 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
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