import SwiftUI

/// FolderMind Design System (FMDesign)
/// Centralized tokens for a superior, consistent UI/UX.
enum FMDesign {
    
    // MARK: - Colors
    enum Color {
        static let logicBlue = SwiftUI.Color(red: 0.15, green: 0.75, blue: 1.0)
        static let logicMagenta = SwiftUI.Color(red: 1.0, green: 0.25, blue: 0.75)
        static let logicGold = SwiftUI.Color(red: 1.0, green: 0.8, blue: 0.2)
        
        static let backgroundDeep = SwiftUI.Color(white: 0.05)
        static let glassTint = SwiftUI.Color.white.opacity(0.05)
        static let glassStroke = SwiftUI.Color.white.opacity(0.15)
    }
    
    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Typography
    enum Font {
        static func mega() -> SwiftUI.Font {
            .system(size: 80, weight: .black, design: .default)
        }

        static func title() -> SwiftUI.Font {
            .system(size: 32, weight: .bold, design: .rounded)
        }
        
        static func headline() -> SwiftUI.Font {
            .system(size: 18, weight: .semibold, design: .default)
        }
        
        static func body() -> SwiftUI.Font {
            .system(size: 15, weight: .regular, design: .default)
        }
        
        static func caption() -> SwiftUI.Font {
            .system(size: 12, weight: .medium, design: .default)
        }
    }
    
    // MARK: - Animation
    enum Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.75)
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let smooth = SwiftUI.Animation.interactiveSpring(response: 0.5, dampingFraction: 0.85)
    }
    
    // MARK: - Layout
    enum Layout {
        static let cornerRadius: CGFloat = 16
        static let glassRadius: CGFloat = 32
    }
}

// MARK: - Extensions
extension View {
    func fmTitle() -> some View {
        self.font(FMDesign.Font.title())
            .tracking(-0.8)
            .foregroundStyle(.white)
    }
    
    func fmMega() -> some View {
        self.font(FMDesign.Font.mega())
            .tracking(-4)
            .foregroundStyle(.white)
    }
    
    func fmWatermark() -> some View {
        self.fmMega()
            .opacity(0.04)
            .blendMode(.overlay)
    }
    
    func fmHeadline() -> some View {
        self.font(FMDesign.Font.headline())
            .foregroundStyle(.secondary)
    }
}
