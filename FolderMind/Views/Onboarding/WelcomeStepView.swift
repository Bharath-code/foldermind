import SwiftUI

struct WelcomeStepView: View {
    @State private var logoScale: CGFloat = 0.7
    @State private var taglineOpacity: Double = 0
    var onAdvance: () -> Void

    var body: some View {
        ZStack {
            // Watermark Layer
            Text("INTENTION")
                .fmWatermark()
                .rotationEffect(.degrees(-90))
                .offset(x: -320)
            
            VStack(spacing: FMDesign.Spacing.xxl) {
                // Hero Section
                VStack(spacing: FMDesign.Spacing.lg) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .scaleEffect(logoScale)
                        .shadow(color: FMDesign.Color.logicBlue.opacity(0.3), radius: 20)
                    
                    VStack(spacing: FMDesign.Spacing.sm) {
                        Text("Welcome to FolderMind")
                            .fmTitle()
                        
                        Text("Automate your chaos into logic.")
                            .fmHeadline()
                            .opacity(taglineOpacity)
                    }
                }
                
                // Feature "Pills" for social proof / features
                HStack(spacing: FMDesign.Spacing.md) {
                    FeaturePill(icon: "bolt.fill", text: "Instant")
                    FeaturePill(icon: "shield.fill", text: "Local-First")
                    FeaturePill(icon: "sparkles", text: "AI-Ready")
                }
                .opacity(taglineOpacity)
                
                Spacer()

                // Action
                FMButton("Get Started") {
                    onAdvance()
                }
            }
            .padding(.vertical, FMDesign.Spacing.xxl)
            .padding(.horizontal, FMDesign.Spacing.xl)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.smooth) {
                logoScale = 1.0
                taglineOpacity = 1.0
            }
        }
    }
}

struct FeaturePill: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.05))
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }
        }
    }
}
