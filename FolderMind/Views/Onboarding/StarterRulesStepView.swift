import SwiftUI

struct StarterRulesStepView: View {
    @Binding var rules: [StarterRule]
    var onAdvance: () -> Void

    private var enabledCount: Int { rules.filter(\.isEnabled).count }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: FMDesign.Spacing.sm) {
                Text("Define\nLogic.")
                    .fmMega()
                    .lineSpacing(-20)
                Text("These activate instantly. You can customise them anytime.")
                    .font(FMDesign.Font.headline())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, FMDesign.Spacing.xl)
            .padding(.bottom, FMDesign.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FMDesign.Spacing.xl)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach($rules) { $rule in
                        StarterRuleRow(rule: $rule)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            Divider()

            HStack {
                Text("\(enabledCount) rule\(enabledCount == 1 ? "" : "s") active")
                    .font(FMDesign.Font.caption())
                    .foregroundStyle(.secondary)
                Spacer()
                FMButton("Continue") { onAdvance() }
                    .disabled(enabledCount == 0)
            }
            .padding(.horizontal, FMDesign.Spacing.xl)
            .padding(.bottom, FMDesign.Spacing.xl)
            .padding(.top, FMDesign.Spacing.md)
        }
    }
}

struct StarterRuleRow: View {
    @Binding var rule: StarterRule

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(rule.color.opacity(rule.isEnabled ? 0.15 : 0.06))
                    .frame(width: 36, height: 36)
                Image(systemName: rule.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(rule.isEnabled ? rule.color : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.system(size: 13, weight: .medium))
                Text(rule.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: $rule.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            ZStack {
                if rule.isEnabled {
                    rule.color.opacity(0.08)
                } else {
                    Color.white.opacity(0.03)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: FMDesign.Layout.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FMDesign.Layout.cornerRadius, style: .continuous)
                    .stroke(rule.isEnabled ? rule.color.opacity(0.3) : FMDesign.Color.glassStroke, lineWidth: 0.5)
            }
        }
        .animation(FMDesign.Animation.quick, value: rule.isEnabled)
        .contentShape(Rectangle())
        .onTapGesture { rule.isEnabled.toggle() }
    }
}
