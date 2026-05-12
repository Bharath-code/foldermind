import SwiftUI

struct DoneStepView: View {
    let filesProcessed: Int
    let minutesSaved: Int
    var onComplete: () -> Void

    @State private var numberScale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Success Counter Hero
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("\(filesProcessed)")
                        .font(.system(size: 240, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FMDesign.Color.logicBlue.opacity(0.4), FMDesign.Color.logicBlue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(numberScale)
                        .offset(x: 60, y: 40)
                        .rotationEffect(.degrees(-5))
                }
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: FMDesign.Spacing.xl) {
                VStack(alignment: .leading, spacing: FMDesign.Spacing.xs) {
                    Text("Logic\nEstablished.")
                        .fmMega()
                        .lineSpacing(-20)
                    
                    Text("Your Mac is now in perfect order.")
                        .font(FMDesign.Font.headline())
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: FMDesign.Spacing.md) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                        Text("~\(minutesSaved) minutes saved per month")
                    }
                    .font(FMDesign.Font.body())
                    .foregroundStyle(FMDesign.Color.logicBlue)
                    
                    Text("Every action is logged. You are in full control.")
                        .font(FMDesign.Font.body())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                FMButton("Enter FolderMind") {
                    onComplete()
                }
            }
            .padding(FMDesign.Spacing.xl)
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
