import SwiftUI

struct StarterRulesStepView: View {
    @Binding var rules: [StarterRule]
    var onAdvance: () -> Void

    private var enabledCount: Int { rules.filter(\.isEnabled).count }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Set up your rules")
                    .font(.system(size: 22, weight: .semibold))
                Text("These activate instantly. You can customise them anytime.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 20)

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
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Continue") { onAdvance() }
                    .buttonStyle(FMPrimaryButtonStyle())
                    .disabled(enabledCount == 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(rule.isEnabled
                      ? rule.color.opacity(0.04)
                      : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(rule.isEnabled
                                      ? rule.color.opacity(0.2)
                                      : Color.secondary.opacity(0.15),
                                      lineWidth: 0.5)
                )
        )
        .animation(.easeInOut(duration: 0.15), value: rule.isEnabled)
        .contentShape(Rectangle())
        .onTapGesture { rule.isEnabled.toggle() }
    }
}
