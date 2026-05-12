import SwiftUI

struct FMButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var style: FMButtonStyleType = .primary
    
    enum FMButtonStyleType {
        case primary
        case secondary
        case ghost
    }
    
    init(_ title: String, icon: String? = nil, style: FMButtonStyleType = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
        }
        .buttonStyle(AdaptiveButtonStyle(style: style))
    }
}

private struct AdaptiveButtonStyle: ButtonStyle {
    let style: FMButton.FMButtonStyleType
    
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26, *) {
            TahoeButtonStyleWrapper(style: style, configuration: configuration)
        } else {
            LegacyButtonStyleWrapper(style: style, configuration: configuration)
        }
    }
}

@available(macOS 26, *)
private struct TahoeButtonStyleWrapper: View {
    let style: FMButton.FMButtonStyleType
    let configuration: ButtonStyle.Configuration
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    var body: some View {
        configuration.label
            .font(FMDesign.Font.headline())
            .foregroundStyle(style == .primary ? (isEnabled ? Color.black : .white.opacity(0.4)) : .primary)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background {
                ZStack {
                    if style == .primary {
                        if isEnabled {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.white)
                                .opacity(configuration.isPressed ? 0.9 : 1.0)
                                .shadow(color: .white.opacity(isHovered ? 0.5 : 0.3), radius: isHovered ? 15 : 10, x: 0, y: 5)
                            
                            // Glass highlight
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        } else {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        }
                    } else if style == .secondary {
                        VisualEffectView(material: .selection, blendingMode: .withinWindow)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(FMDesign.Color.glassStroke, lineWidth: 0.5)
                            }
                            .opacity(isHovered ? 1.0 : 0.8)
                    } else {
                        // Ghost
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
                    }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : (isHovered && isEnabled ? 1.02 : 1.0))
            .onHover { isHovered = $0 }
    }
}

private struct LegacyButtonStyleWrapper: View {
    let style: FMButton.FMButtonStyleType
    let configuration: ButtonStyle.Configuration
    @Environment(\.isEnabled) private var isEnabled
    
    var body: some View {
        configuration.label
            .font(FMDesign.Font.headline())
            .foregroundStyle(style == .primary ? .white : .primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: FMDesign.Layout.cornerRadius)
                    .fill(isEnabled 
                          ? (style == .primary ? FMDesign.Color.logicBlue : Color.secondary.opacity(0.2))
                          : Color.secondary.opacity(0.3))
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}
