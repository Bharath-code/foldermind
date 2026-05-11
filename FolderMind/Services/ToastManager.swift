import SwiftUI
import Combine

enum ToastType {
    case info
    case success
    case warning
    case error
    
    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    var duration: Double = 3.5
}

@MainActor
class ToastManager: ObservableObject {
    @Published var currentToast: Toast?
    private var toastQueue: [Toast] = []
    private var timer: AnyCancellable?
    
    // Throttling state for bulk operations
    private var pendingCount = 0
    private var lastAction: String?
    private var lastFilename: String?
    private var lastDestination: String?
    private var debounceTimer: AnyCancellable?

    func show(_ message: String, type: ToastType = .info) {
        let newToast = Toast(message: message, type: type)
        
        if currentToast == nil {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentToast = newToast
            }
            startTimer(for: newToast)
        } else {
            // If the same message is already in queue or showing, ignore
            if currentToast?.message == message || toastQueue.contains(where: { $0.message == message }) {
                return
            }
            toastQueue.append(newToast)
        }
    }
    
    /// Specialized method for file operations to handle throttling
    func showFileAction(_ action: String, filename: String, destination: String? = nil) {
        pendingCount += 1
        lastAction = action
        lastFilename = filename
        lastDestination = destination
        
        // If a timer is already running, don't restart it.
        // This ensures that even during constant file operations, 
        // we still flush and show a toast every 800ms.
        if debounceTimer == nil {
            debounceTimer = Just(())
                .delay(for: .milliseconds(800), scheduler: RunLoop.main)
                .sink { [weak self] _ in
                    self?.flushBulkActions()
                    self?.debounceTimer = nil
                }
        }
    }
    
    private func flushBulkActions() {
        guard let action = lastAction, pendingCount > 0 else { return }
        
        let message: String
        if pendingCount == 1 {
            let file = lastFilename ?? "file"
            if let dest = lastDestination {
                message = "\(action) \(file) to \(dest)"
            } else {
                message = "Successfully \(action.lowercased()) \(file)"
            }
        } else {
            message = "\(action) \(pendingCount) files"
        }
        
        show(message, type: .success)
        
        // Reset counters
        pendingCount = 0
        lastAction = nil
        lastFilename = nil
        lastDestination = nil
    }

    private func startTimer(for toast: Toast) {
        timer?.cancel()
        timer = Just(())
            .delay(for: .seconds(toast.duration), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.dismiss()
            }
    }

    func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentToast = nil
        }
        
        // Show next if any
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if !self.toastQueue.isEmpty {
                let next = self.toastQueue.removeFirst()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.currentToast = next
                }
                self.startTimer(for: next)
            }
        }
    }
}
