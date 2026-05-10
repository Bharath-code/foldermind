import SwiftUI
import AppKit

struct WindowConfigurator: NSViewRepresentable {
    let config: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                config(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    /// Accesses the underlying NSWindow to apply custom configurations
    func configureWindow(config: @escaping (NSWindow) -> Void) -> some View {
        background(WindowConfigurator(config: config))
    }
    
    /// Applies standard onboarding window styling: fixed size, hidden traffic lights
    func onboardingWindowStyle() -> some View {
        self.configureWindow { window in
            window.styleMask.remove(.resizable)
            window.styleMask.remove(.miniaturizable)
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
        }
        .frame(width: 600, height: 480)
    }
}
