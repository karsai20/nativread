import SwiftUI

struct TypographyPanel: View {
    @EnvironmentObject private var settings: ReaderSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Theme
                Section("Theme") {
                    HStack(spacing: 12) {
                        ForEach(ReaderSettings.ReaderTheme.allCases, id: \.rawValue) { theme in
                            ThemeButton(theme: theme, isSelected: settings.theme == theme) {
                                settings.theme = theme
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .frame(maxWidth: .infinity)
                }

                // Font Size
                Section("Font Size") {
                    HStack {
                        Text("A")
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(.secondary)
                        Slider(value: $settings.fontSize, in: 13...24, step: 1)
                        Text("A")
                            .font(.system(size: 20, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                    Text("Sample text at \(Int(settings.fontSize))pt")
                        .font(.custom(settings.fontFamily, size: settings.fontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Line Spacing
                Section("Line Spacing") {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease")
                            .foregroundStyle(.secondary)
                        Slider(value: $settings.lineHeight, in: 1.3...2.2, step: 0.05)
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                    }
                    Text("Spacing: \(String(format: "%.2f", settings.lineHeight))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Margins
                Section("Margins") {
                    HStack {
                        Image(systemName: "arrow.left.and.right")
                            .foregroundStyle(.secondary)
                        Slider(value: $settings.marginSize, in: 12...56, step: 4)
                    }
                    Text("Margin: \(Int(settings.marginSize))pt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Font Family
                Section("Typeface") {
                    ForEach(ReaderSettings.FontFamily.allCases, id: \.rawValue) { family in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(family.displayName)
                                    .font(.system(size: 15))
                                Text("The quick brown fox")
                                    .font(.custom(family.rawValue, size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if settings.fontFamily == family.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.primary)
                                    .fontWeight(.medium)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { settings.fontFamily = family.rawValue }
                    }
                }
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - ThemeButton

private struct ThemeButton: View {
    let theme: ReaderSettings.ReaderTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.backgroundColor)
                    .frame(width: 70, height: 44)
                    .overlay {
                        Text("Aa")
                            .font(.system(size: 14, design: .serif))
                            .foregroundStyle(theme.textColor)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.primary : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    }

                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
