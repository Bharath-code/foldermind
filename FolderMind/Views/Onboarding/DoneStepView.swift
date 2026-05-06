import SwiftUI

struct DoneStepView: View {
    let filesProcessed: Int
    let minutesSaved: Int
    var onComplete: () -> Void

    @State private var numberScale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 4) {
                Text("\(filesProcessed)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .scaleEffect(numberScale)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: numberScale)
                Text("files just found a home")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 13))
                Text("~\(minutesSaved) minutes of sorting you'll never do manually")
                    .font(.system(size: 13))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.08))
            )

            Text("All reversible. Every action is logged in the activity feed.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button("Start using FolderMind") {
                onComplete()
            }
            .buttonStyle(FMPrimaryButtonStyle())
            .padding(.bottom, 40)
        }
        .opacity(contentOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) { contentOpacity = 1 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.1)) {
                numberScale = 1.0
            }
        }
    }
}
