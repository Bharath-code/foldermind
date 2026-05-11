import SwiftUI

struct ToastView: View {
    let toast: Toast
    var onDismiss: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated Icon
            ZStack {
                Circle()
                    .fill(toast.type.color.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: toast.type.icon)
                    .foregroundStyle(toast.type.color)
                    .font(.system(size: 14, weight: .bold))
            }
            
            // Message
            Text(toast.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer(minLength: 20)
            
            // Dismiss Button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .background(isHovering ? Color.primary.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            ZStack {
                // Liquid Glass Background
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.05), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .frame(minWidth: 280, maxWidth: 400)
    }
}

struct ToastContainerView: View {
    @ObservedObject var manager: ToastManager
    
    var body: some View {
        VStack {
            Spacer()
            if let toast = manager.currentToast {
                ToastView(toast: toast) {
                    manager.dismiss()
                }
                .padding(.bottom, 30) // Offset from the bottom edge
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9, anchor: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    )
                )
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea()
        .zIndex(999)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        
        ToastView(toast: Toast(message: "Moved 'Invoice.pdf' to Documents", type: .success)) {
            print("Dismissed")
        }
    }
    .padding()
}
