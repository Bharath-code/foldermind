import SwiftUI

struct WelcomeStepView: View {
    @State private var logoScale: CGFloat = 0.7
    @State private var taglineOpacity: Double = 0
    var onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .scaleEffect(logoScale)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: logoScale)

            VStack(spacing: 8) {
                Text("FolderMind")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))

                Text("Your Mac. Finally organised.")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.secondary)
                    .opacity(taglineOpacity)
                    .animation(.easeIn(duration: 0.4).delay(0.3), value: taglineOpacity)
            }

            Spacer()

            Button("Get started") {
                onAdvance()
            }
            .buttonStyle(FMPrimaryButtonStyle())
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            logoScale = 1.0
            taglineOpacity = 1.0
        }
    }
}
