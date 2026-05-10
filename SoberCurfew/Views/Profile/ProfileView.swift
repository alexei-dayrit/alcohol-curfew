import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    @Environment(HealthKitManager.self) private var healthKit
    @Environment(NotificationManager.self) private var notifications
    @State private var saved = false

    // Basic physiology
    @State private var weightLbs: Double = 175
    @State private var selectedSex: BiologicalSex = .male
    @State private var bedtimeDate = defaultBedtime()
    @State private var healthKitEnabled = false

    // Ultra calibration
    @State private var heightCm: Double = 170
    @State private var age: Int = 30
    @State private var bodyComposition: BodyComposition = .average
    @State private var toleranceLevel: ToleranceLevel = .standard
    @State private var sessionFoodState: FoodState = .light

    // Hydration reminders
    @State private var hydrationRemindersEnabled = false
    @State private var hydrationReminderIntervalMinutes = 30

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                physiologyCard
                ultraCalibrationCard
                bedtimeCard
                healthKitCard
                hydrationCard
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
                Text("These values personalize your BAC calculation.")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)

                divider

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

    private var ultraCalibrationCard: some View {
        BentoCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("ULTRA CALIBRATION")
                Text("Enables the Watson formula for more accurate volume of distribution. Optional but recommended.")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)

                divider

                // Height
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        sectionHeader("HEIGHT")
                        Spacer()
                        Text(heightCm > 0 ? "\(Int(heightCm)) cm  ·  \(heightFtIn)" : "Not set")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(heightCm > 0 ? .white : .textSecondary)
                    }
                    Slider(value: $heightCm, in: 120...220, step: 1)
                        .tint(.accentAmber)
                }

                divider

                // Age
                HStack {
                    sectionHeader("AGE")
                    Spacer()
                    Stepper("\(age > 0 ? "\(age) yrs" : "Not set")", value: $age, in: 0...100)
                        .fixedSize()
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                divider

                // Body composition
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("BODY COMPOSITION")
                    HStack(spacing: 8) {
                        ForEach(BodyComposition.allCases, id: \.self) { option in
                            selectionButton(
                                label: option.rawValue,
                                isSelected: bodyComposition == option
                            ) { bodyComposition = option }
                        }
                    }
                }

                divider

                // Tolerance
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("METABOLIC TOLERANCE")
                    HStack(spacing: 8) {
                        ForEach(ToleranceLevel.allCases, id: \.self) { option in
                            selectionButton(
                                label: option.rawValue,
                                isSelected: toleranceLevel == option
                            ) { toleranceLevel = option }
                        }
                    }
                }

                divider

                // Session food state
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("SESSION FOOD STATE")
                    Text("Default stomach contents when logging a drink this session.")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                    HStack(spacing: 8) {
                        ForEach(FoodState.allCases, id: \.self) { option in
                            selectionButton(
                                label: "\(option.icon) \(option.rawValue)",
                                isSelected: sessionFoodState == option
                            ) { sessionFoodState = option }
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

    private var hydrationCard: some View {
        BentoCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("HYDRATION REMINDERS")

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Remind me to hydrate")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Sends a notification while BAC is above zero.")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $hydrationRemindersEnabled)
                        .tint(.accentAmber)
                        .onChange(of: hydrationRemindersEnabled) { _, enabled in
                            if enabled {
                                Task { await notifications.requestAuthorization() }
                            }
                        }
                }

                if hydrationRemindersEnabled {
                    divider
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("REMINDER INTERVAL")
                        HStack(spacing: 8) {
                            ForEach([15, 30, 45, 60], id: \.self) { minutes in
                                selectionButton(
                                    label: "\(minutes)m",
                                    isSelected: hydrationReminderIntervalMinutes == minutes
                                ) { hydrationReminderIntervalMinutes = minutes }
                            }
                        }
                    }
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

    @ViewBuilder
    private func selectionButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .black : .textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.accentAmber : Color.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Divider().background(Color.white.opacity(0.08))
    }

    private var heightFtIn: String {
        let totalInches = heightCm / 2.54
        let feet = Int(totalInches) / 12
        let inches = Int(totalInches) % 12
        return "\(feet)'\(inches)\""
    }

    private func loadProfile() {
        guard let p = profile else { return }
        weightLbs = p.weightLbs
        selectedSex = p.biologicalSex
        bedtimeDate = Self.bedtimeDateFrom(hour: p.bedtimeHour, minute: p.bedtimeMinute)
        healthKitEnabled = p.healthKitEnabled
        heightCm = p.heightCm
        age = p.age
        bodyComposition = p.bodyComposition
        toleranceLevel = p.toleranceLevel
        sessionFoodState = p.sessionFoodState
        hydrationRemindersEnabled = p.hydrationRemindersEnabled
        hydrationReminderIntervalMinutes = p.hydrationReminderIntervalMinutes
    }

    private func saveProfile() {
        let bedComponents = Calendar.current.dateComponents([.hour, .minute], from: bedtimeDate)
        let p = UserProfile.fetchOrCreate(in: modelContext)
        p.weightLbs = weightLbs
        p.biologicalSex = selectedSex
        p.bedtimeHour = bedComponents.hour ?? 23
        p.bedtimeMinute = bedComponents.minute ?? 0
        p.healthKitEnabled = healthKitEnabled
        p.heightCm = heightCm
        p.age = age
        p.bodyComposition = bodyComposition
        p.toleranceLevel = toleranceLevel
        p.sessionFoodState = sessionFoodState
        p.hydrationRemindersEnabled = hydrationRemindersEnabled
        p.hydrationReminderIntervalMinutes = hydrationReminderIntervalMinutes
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
