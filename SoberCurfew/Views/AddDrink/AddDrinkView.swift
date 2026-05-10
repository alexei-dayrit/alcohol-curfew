import SwiftUI
import SwiftData

private enum LogMode: String, CaseIterable {
    case ultra = "Ultra"
    case quick = "Quick"
}

private enum QuickSize: String, CaseIterable {
    case small  = "S"
    case medium = "M"
    case large  = "L"

    func volumeML(for category: DrinkCategory) -> Double {
        switch (category, self) {
        case (.beer,    .small):  return 355
        case (.beer,    .medium): return 473
        case (.beer,    .large):  return 568
        case (.wine,    .small):  return 120
        case (.wine,    .medium): return 150
        case (.wine,    .large):  return 200
        case (.spirits, .small):  return 30
        case (.spirits, .medium): return 44
        case (.spirits, .large):  return 60
        default:                  return 150   // cocktail / custom
        }
    }

    func abv(for category: DrinkCategory) -> Double {
        switch (category, self) {
        case (.beer,    .small):  return 0.045
        case (.beer,    .medium): return 0.050
        case (.beer,    .large):  return 0.055
        case (.wine,    .small):  return 0.12
        case (.wine,    .medium): return 0.13
        case (.wine,    .large):  return 0.14
        case (.spirits, _):       return 0.40
        case (_, .small):         return 0.12
        case (_, .medium):        return 0.14
        case (_, .large):         return 0.15
        }
    }
}

private let quickOffsets: [(label: String, seconds: Int)] = [
    ("Just now", 0),
    ("15 min",   900),
    ("30 min",   1800),
    ("1 hr",     3600),
]

private let quickCategories: [(category: DrinkCategory, label: String)] = [
    (.beer,    "🍺 Beer"),
    (.wine,    "🍷 Wine"),
    (.spirits, "🥃 Shot"),
    (.custom,  "🍹 Cocktail"),
]

struct AddDrinkView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    @State private var mode: LogMode = .ultra

    // Ultra state
    @State private var selectedPreset: PresetDrink?
    @State private var showManualEntry = false
    @State private var volumeText = "100"
    @State private var abvText = "5.0"
    @State private var customName = ""
    @State private var isCarbonated = false
    @State private var foodOverride: FoodState? = nil   // nil = use session default

    // Quick state
    @State private var quickCategory: DrinkCategory = .beer
    @State private var quickSize: QuickSize = .medium
    @State private var quickOffsetSeconds: Int = 0
    @State private var isLogging = false

    private var profile: UserProfile { profiles.first ?? UserProfile() }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    modePicker
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 20)

                    if mode == .ultra {
                        ultraContent
                    } else {
                        quickContent
                    }
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Log Drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                }
                if mode == .ultra {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add") { addUltraDrink() }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(canAddUltra ? .accentAmber : .textSecondary)
                            .disabled(!canAddUltra)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(LogMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { mode = m }
                } label: {
                    VStack(spacing: 4) {
                        Text(m.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(mode == m ? .black : .textSecondary)
                        if m == .ultra {
                            Text("Detailed · Watson formula")
                                .font(.system(size: 10))
                                .foregroundColor(mode == m ? .black.opacity(0.6) : .textSecondary.opacity(0.6))
                        } else {
                            Text("Fast · no numbers needed")
                                .font(.system(size: 10))
                                .foregroundColor(mode == m ? .black.opacity(0.6) : .textSecondary.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(mode == m ? Color.accentAmber : Color.cardBackgroundSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Ultra content

    private var ultraContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("QUICK LOG")
                    .padding(.horizontal, 16)

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
                .padding(.horizontal, 16)
            }

            // Modifiers (shown when a selection exists)
            if selectedPreset != nil || showManualEntry {
                drinkModifiersCard
                    .padding(.horizontal, 16)
            }

            // Manual entry
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showManualEntry.toggle() }
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
                .padding(.horizontal, 16)

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
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            disclaimer
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    private var drinkModifiersCard: some View {
        BentoCard {
            VStack(alignment: .leading, spacing: 14) {
                // Carbonated toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Carbonated")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Beer, sparkling wine, soda mixer — absorbs faster")
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $isCarbonated)
                        .tint(.accentAmber)
                        .labelsHidden()
                }

                Divider().background(Color.white.opacity(0.08))

                // Food state override
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Stomach contents")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        if foodOverride != nil {
                            Button("Reset to session") {
                                foodOverride = nil
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(FoodState.allCases, id: \.self) { state in
                            let isSelected = (foodOverride ?? profile.sessionFoodState) == state
                            Button {
                                foodOverride = state
                            } label: {
                                Text("\(state.icon) \(state.rawValue)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(isSelected ? .black : .textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(isSelected ? Color.accentAmber : Color.cardBackgroundSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Quick content

    private var quickContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Category grid
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("WHAT ARE YOU DRINKING?")
                    .padding(.horizontal, 16)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    ForEach(quickCategories, id: \.category) { item in
                        let isSelected = quickCategory == item.category
                        Button { quickCategory = item.category } label: {
                            Text(item.label)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isSelected ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                                .background(isSelected ? Color.accentAmber : Color.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.06), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Size picker
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("HOW BIG?")
                    .padding(.horizontal, 16)

                HStack(spacing: 10) {
                    ForEach(QuickSize.allCases, id: \.self) { size in
                        let isSelected = quickSize == size
                        Button { quickSize = size } label: {
                            Text(size.rawValue)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(isSelected ? .black : .textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(isSelected ? Color.accentAmber : Color.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Time offset
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("WHEN DID YOU HAVE IT?")
                    .padding(.horizontal, 16)

                HStack(spacing: 8) {
                    ForEach(quickOffsets, id: \.seconds) { offset in
                        let isSelected = quickOffsetSeconds == offset.seconds
                        Button { quickOffsetSeconds = offset.seconds } label: {
                            Text(offset.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(isSelected ? .black : .textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(isSelected ? Color.accentAmber : Color.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Log button
            Button {
                guard !isLogging else { return }
                isLogging = true
                addQuickDrink()
            } label: {
                Text("LOG IT")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.accentAmber)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            disclaimer
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    // MARK: - Shared subviews

    private var disclaimer: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.sleepYellow)
            Text("Estimates only. Never drive under the influence.")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
        }
    }

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

    private var canAddUltra: Bool {
        selectedPreset != nil || (showManualEntry && validManualEntry)
    }

    private var validManualEntry: Bool {
        guard let vol = Double(volumeText), let abv = Double(abvText) else { return false }
        return vol > 0 && abv > 0 && abv <= 100
    }

    private func addUltraDrink() {
        let food = foodOverride ?? profile.sessionFoodState
        if let preset = selectedPreset {
            modelContext.insert(DrinkEntry(
                name: preset.name,
                category: preset.category,
                volumeML: preset.volumeML,
                abv: preset.abv,
                isCarbonated: isCarbonated,
                timestampOffsetSec: 0,
                foodStateAtTime: food
            ))
        } else if showManualEntry, let vol = Double(volumeText), let abv = Double(abvText) {
            modelContext.insert(DrinkEntry(
                name: customName.isEmpty ? "Custom Drink" : customName,
                category: .custom,
                volumeML: vol,
                abv: abv / 100.0,
                isCarbonated: isCarbonated,
                timestampOffsetSec: 0,
                foodStateAtTime: food
            ))
        }
        dismiss()
    }

    private func addQuickDrink() {
        let vol = quickSize.volumeML(for: quickCategory)
        let abv = quickSize.abv(for: quickCategory)
        let name: String
        switch quickCategory {
        case .beer:    name = "\(quickSize.rawValue) Beer"
        case .wine:    name = "\(quickSize.rawValue) Wine"
        case .spirits: name = quickSize == .small ? "Shot" : "\(quickSize.rawValue) Shot"
        case .custom:  name = "\(quickSize.rawValue) Cocktail"
        }
        modelContext.insert(DrinkEntry(
            name: name,
            category: quickCategory,
            volumeML: vol,
            abv: abv,
            isCarbonated: false,
            timestampOffsetSec: quickOffsetSeconds,
            foodStateAtTime: profile.sessionFoodState
        ))
        dismiss()
    }
}
