import SwiftUI
import AppKit

struct LiquidGlassModifier: ViewModifier {
    var radius: CGFloat = FMDesign.Layout.glassRadius
    var opacity: Double = 0.6
    
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Deep refraction layer
                    VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    
                    // Glass tint
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.05), .black.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                }
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            }
    }
}

extension View {
    func liquidGlass(radius: CGFloat = FMDesign.Layout.glassRadius) -> some View {
        self.modifier(LiquidGlassModifier(radius: radius))
    }
}

// MARK: - Tahoe Button Style
struct TahoeButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FMDesign.Font.headline())
            .foregroundStyle(isEnabled ? Color.black : .white.opacity(0.4))
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background {
                ZStack {
                    if isEnabled {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white)
                            .opacity(configuration.isPressed ? 0.9 : 1.0)
                            .shadow(color: .white.opacity(isHovered ? 0.4 : 0.2), radius: isHovered ? 15 : 10, x: 0, y: 5)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : (isHovered && isEnabled ? 1.02 : 1.0))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Liquid Glass Container
struct LiquidGlassContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background {
                VisualEffectView(material: .selection, blendingMode: .withinWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(FMDesign.Color.glassStroke, lineWidth: 0.5)
                    }
            }
    }
}

// MARK: - AppKit VisualEffect
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
