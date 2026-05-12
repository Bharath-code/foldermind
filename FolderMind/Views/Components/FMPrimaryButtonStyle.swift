import SwiftUI

struct FMPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FMDesign.Font.headline())
            .foregroundStyle(.white)
            .padding(.horizontal, FMDesign.Spacing.xl)
            .padding(.vertical, FMDesign.Spacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: FMDesign.Layout.cornerRadius)
                    .fill(isEnabled
                          ? FMDesign.Color.logicBlue
                          : SwiftUI.Color.secondary.opacity(0.3))
                    .shadow(color: isEnabled ? FMDesign.Color.logicBlue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(FMDesign.Animation.quick, value: configuration.isPressed)
    }
}
