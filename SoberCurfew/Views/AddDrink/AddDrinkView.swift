import SwiftUI
import SwiftData

struct AddDrinkView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: PresetDrink?
    @State private var showManualEntry = false
    @State private var volumeText = "100"
    @State private var abvText = "5.0"
    @State private var customName = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Quick select grid
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("QUICK LOG")

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(PresetDrink.all) { preset in
                                DrinkTypeCard(
                                    preset: preset,
                                    isSelected: selectedPreset?.id == preset.id
                                ) {
                                    selectedPreset = preset
                                    showManualEntry = false
                                }
                            }
                        }
                    }

                    // Manual entry expandable section
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showManualEntry.toggle()
                            }
                            if showManualEntry { selectedPreset = nil }
                        } label: {
                            HStack {
                                sectionHeader("MANUAL ENTRY")
                                    .foregroundColor(showManualEntry ? .accentAmber : .textSecondary)
                                Spacer()
                                Image(systemName: showManualEntry ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.textSecondary)
                            }
                        }

                        if showManualEntry {
                            BentoCard {
                                VStack(spacing: 16) {
                                    HStack(spacing: 20) {
                                        inputField(label: "VOLUME (mL)", text: $volumeText)
                                        Divider().background(Color.white.opacity(0.1))
                                        inputField(label: "ABV (%)", text: $abvText)
                                    }

                                    TextField("Drink name (optional)", text: $customName)
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                        .padding(.vertical, 8)
                                        .overlay(
                                            Rectangle()
                                                .frame(height: 1)
                                                .foregroundColor(Color.white.opacity(0.1)),
                                            alignment: .bottom
                                        )
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    // Disclaimer
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.sleepYellow)
                        Text("Estimates only. Never drive under the influence.")
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Log Drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { addDrink() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(canAdd ? .accentAmber : .textSecondary)
                        .disabled(!canAdd)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.textSecondary)
            .tracking(1.5)
    }

    @ViewBuilder
    private func inputField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.textSecondary)
                .tracking(1)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Logic

    private var canAdd: Bool {
        selectedPreset != nil || (showManualEntry && validManualEntry)
    }

    private var validManualEntry: Bool {
        guard let vol = Double(volumeText), let abv = Double(abvText) else { return false }
        return vol > 0 && abv > 0 && abv <= 100
    }

    private func addDrink() {
        if let preset = selectedPreset {
            modelContext.insert(DrinkEntry(
                name: preset.name,
                category: preset.category,
                volumeML: preset.volumeML,
                abv: preset.abv
            ))
        } else if showManualEntry, let vol = Double(volumeText), let abv = Double(abvText) {
            modelContext.insert(DrinkEntry(
                name: customName.isEmpty ? "Custom Drink" : customName,
                category: .custom,
                volumeML: vol,
                abv: abv / 100.0
            ))
        }
        dismiss()
    }
}
