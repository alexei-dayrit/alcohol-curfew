import SwiftUI
import SwiftData

private let appGroupID = "group.com.sobercurfew.app"

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(NotificationManager.self) private var notifications
    @Query(sort: \DrinkEntry.timestamp, order: .reverse) private var allDrinks: [DrinkEntry]
    @Query private var profiles: [UserProfile]

    @State private var showAddDrink = false
    @State private var metabolism = MetabolismManager()

    @State private var currentBAC: Double = 0
    @State private var soberTime: Date?
    @State private var bacProgress: Double = 0
    @State private var sleepImpact: SleepImpact = .optimal
    @State private var isAbsorbing: Bool = false

    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var profile: UserProfile { profiles.first ?? UserProfile() }

    private var recentDrinks: [DrinkEntry] {
        let cutoff = Date().addingTimeInterval(-12 * 3600)
        return allDrinks.filter { $0.effectiveTimestamp > cutoff }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    BentoCard(padding: 24) {
                        ZeroLineGaugeView(
                            bac: currentBAC,
                            progress: bacProgress,
                            soberTime: soberTime,
                            isAbsorbing: isAbsorbing
                        )
                        .frame(height: 256)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        SleepImpactTile(impact: sleepImpact, soberTime: soberTime)
                            .frame(maxWidth: .infinity)

                        Button { showAddDrink = true } label: {
                            quickLogButton
                        }
                        .buttonStyle(.plain)
                        .frame(width: 110)
                    }

                    if isAbsorbing {
                        absorbingBanner
                    }

                    HStack(spacing: 12) {
                        StatTile(
                            label: "LAST DRINK",
                            value: recentDrinks.first?.name ?? "—",
                            subtitle: recentDrinks.first.map {
                                $0.effectiveTimestamp.formatted(date: .omitted, time: .shortened)
                            }
                        )
                        StatTile(
                            label: "ESTIMATED BAC",
                            value: currentBAC.bacFormatted,
                            subtitle: currentBAC > 0 ? "g/dL blood" : "Clear"
                        )
                    }

                    HStack(spacing: 12) {
                        StatTile(
                            label: "DRINKS TODAY",
                            value: "\(recentDrinks.count)",
                            subtitle: recentDrinks.isEmpty
                                ? "Stay hydrated"
                                : String(format: "%.1f standard", recentDrinks.reduce(0) { $0 + $1.standardDrinks })
                        )
                        StatTile(
                            label: "TIME TO SOBER",
                            value: soberTime.map { $0.formatted(date: .omitted, time: .shortened) } ?? "Clear",
                            subtitle: soberTime.map { countdownLabel($0) } ?? "No alcohol detected"
                        )
                    }

                    Text("ESTIMATES ONLY · NEVER DRIVE UNDER THE INFLUENCE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.textSecondary.opacity(0.5))
                        .tracking(1)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("SoberCurfew")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { SleepCurfewView() } label: {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(.accentBlue)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { ProfileView() } label: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showAddDrink, onDismiss: refreshBAC) {
                AddDrinkView()
            }
            .onAppear(perform: refreshBAC)
            .onReceive(refreshTimer) { _ in refreshBAC() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private var quickLogButton: some View {
        BentoCard(padding: 14) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.accentAmber.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.accentAmber)
                }
                Text("LOG\nDRINK")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.textSecondary)
                    .tracking(1.2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var absorbingBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(.accentAmber)
            Text("Still absorbing · BAC still rising")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.accentAmber)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.accentAmber.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentAmber.opacity(0.25), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Helpers

    private func refreshBAC() {
        currentBAC = metabolism.currentBAC(drinks: recentDrinks, profile: profile)
        soberTime = metabolism.timeToZero(drinks: recentDrinks, profile: profile)
        bacProgress = metabolism.bacProgress(drinks: recentDrinks, profile: profile)
        sleepImpact = metabolism.sleepImpact(
            drinks: recentDrinks,
            profile: profile,
            bedtime: profile.bedtimeDate
        )
        isAbsorbing = metabolism.isAbsorbing(drinks: recentDrinks)
        writeToAppGroup()
        if profile.healthKitEnabled && currentBAC > 0 {
            Task { await healthKit.writeBACSample(currentBAC) }
        }
        if profile.hydrationRemindersEnabled && currentBAC > 0 {
            Task { await notifications.scheduleHydrationReminder(in: profile.hydrationReminderIntervalMinutes) }
        } else {
            notifications.cancelHydrationReminders()
        }
    }

    private func writeToAppGroup() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(currentBAC, forKey: "bac")
        defaults.set(soberTime?.timeIntervalSince1970 ?? 0, forKey: "soberTime")
        defaults.set(sleepImpact.widgetImpactKey, forKey: "impact")
    }

    private func countdownLabel(_ date: Date) -> String {
        let secs = date.timeIntervalSince(.now)
        guard secs > 0 else { return "Clearing now" }
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        return h > 0 ? "in \(h)h \(m)m" : "in \(m)m"
    }
}

private extension SleepImpact {
    var widgetImpactKey: String {
        switch self {
        case .optimal:   return "optimal"
        case .reduced:   return "reduced"
        case .disrupted: return "disrupted"
        }
    }
}
