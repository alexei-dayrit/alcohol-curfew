import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var healthKit = HealthKitManager()
    @State private var saved = false

    // Local editing state
    @State private var weightLbs: Double = 175
    @State private var selectedSex: BiologicalSex = .male
    @State private var bedtimeDate = defaultBedtime()
    @State private var healthKitEnabled = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                physiologyCard
                bedtimeCard
                healthKitCard
                saveButton

                Text("ESTIMATES ONLY · NEVER DRIVE UNDER THE INFLUENCE")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.textSecondary.opacity(0.4))
                    .tracking(1)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Profile & Settings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear(perform: loadProfile)
        .overlay(savedOverlay)
    }

    // MARK: - Cards

    private var physiologyCard: some View {
        BentoCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("PERSONAL PHYSIOLOGY")

                Text("These values personalize your Widmark BAC calculation.")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)

                divider

                // Weight slider
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        sectionHeader("BODY WEIGHT")
                        Spacer()
                        Text("\(Int(weightLbs)) lbs")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Slider(value: $weightLbs, in: 90...350, step: 1)
                        .tint(.accentAmber)
                }

                divider

                // Biological sex toggle
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("BIOLOGICAL SEX")
                    HStack(spacing: 8) {
                        ForEach(BiologicalSex.allCases, id: \.self) { sex in
                            Button {
                                selectedSex = sex
                            } label: {
                                Text(sex.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(selectedSex == sex ? .black : .textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedSex == sex ? Color.accentAmber : Color.cardBackgroundSecondary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var bedtimeCard: some View {
        BentoCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("BEDTIME")
                HStack {
                    Text("Your target sleep time is used to predict the Curfew window.")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                    Spacer()
                    DatePicker("", selection: $bedtimeDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(.accentAmber)
                }
            }
        }
    }

    private var healthKitCard: some View {
        BentoCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("HEALTHKIT SYNC")

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Enable HealthKit")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Sync weight, biological sex, and BAC data.")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $healthKitEnabled)
                        .tint(.accentAmber)
                        .onChange(of: healthKitEnabled) { _, enabled in
                            if enabled {
                                Task { await healthKit.requestAuthorization() }
                            }
                        }
                }

                if healthKitEnabled {
                    Button {
                        Task { await syncFromHealthKit() }
                    } label: {
                        Label("Sync from HealthKit", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.accentBlue)
                    }
                    .padding(.top, 4)
                }

                if let error = healthKit.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.sleepRed)
                }
            }
        }
    }

    private var saveButton: some View {
        Button(action: saveProfile) {
            Text("Save Profile")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentAmber)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var savedOverlay: some View {
        if saved {
            VStack {
                Spacer()
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentAmber)
                    .clipShape(Capsule())
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.textSecondary)
            .tracking(1.5)
    }

    private var divider: some View {
        Divider().background(Color.white.opacity(0.08))
    }

    private func loadProfile() {
        guard let p = profile else { return }
        weightLbs = p.weightLbs
        selectedSex = p.biologicalSex
        bedtimeDate = bedtimeDateFrom(hour: p.bedtimeHour, minute: p.bedtimeMinute)
        healthKitEnabled = p.healthKitEnabled
    }

    private func saveProfile() {
        let bedComponents = Calendar.current.dateComponents([.hour, .minute], from: bedtimeDate)
        if let existing = profile {
            existing.weightLbs = weightLbs
            existing.biologicalSex = selectedSex
            existing.bedtimeHour = bedComponents.hour ?? 23
            existing.bedtimeMinute = bedComponents.minute ?? 0
            existing.healthKitEnabled = healthKitEnabled
        } else {
            let p = UserProfile()
            p.weightLbs = weightLbs
            p.biologicalSex = selectedSex
            p.bedtimeHour = bedComponents.hour ?? 23
            p.bedtimeMinute = bedComponents.minute ?? 0
            p.healthKitEnabled = healthKitEnabled
            p.hasAcceptedDisclaimer = true
            modelContext.insert(p)
        }
        withAnimation(.spring()) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { saved = false }
        }
    }

    private func syncFromHealthKit() async {
        if let sex = healthKit.fetchBiologicalSex() {
            selectedSex = sex
        }
        if let kg = await healthKit.fetchLatestWeightKg() {
            weightLbs = kg * 2.20462
        }
    }

    private static func defaultBedtime() -> Date {
        bedtimeDateFrom(hour: 23, minute: 0)
    }

    private static func bedtimeDateFrom(hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            from: DateComponents(hour: hour, minute: minute)
        ) ?? .now
    }
}

private func bedtimeDateFrom(hour: Int, minute: Int) -> Date {
    Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
}
