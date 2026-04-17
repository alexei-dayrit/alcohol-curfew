import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DrinkEntry.timestamp, order: .reverse) private var allDrinks: [DrinkEntry]
    @Query private var profiles: [UserProfile]

    @State private var showAddDrink = false
    @State private var metabolism = MetabolismManager()

    // Recalculated every 30 seconds via the timer
    @State private var currentBAC: Double = 0
    @State private var soberTime: Date?
    @State private var bacProgress: Double = 0
    @State private var sleepImpact: SleepImpact = .optimal

    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var profile: UserProfile { profiles.first ?? UserProfile() }

    // Only drinks within the last 12 hours contribute to the current BAC window
    private var recentDrinks: [DrinkEntry] {
        let cutoff = Date().addingTimeInterval(-12 * 3600)
        return allDrinks.filter { $0.timestamp > cutoff }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // ── Large tile: ZeroLine gauge ──────────────────────────
                    BentoCard(padding: 24) {
                        ZeroLineGaugeView(
                            bac: currentBAC,
                            progress: bacProgress,
                            soberTime: soberTime
                        )
                        .frame(height: 256)
                    }

                    // ── Medium row: Sleep Impact + Quick Log ────────────────
                    HStack(alignment: .top, spacing: 12) {
                        SleepImpactTile(impact: sleepImpact, soberTime: soberTime)
                            .frame(maxWidth: .infinity)

                        Button { showAddDrink = true } label: {
                            quickLogButton
                        }
                        .buttonStyle(.plain)
                        .frame(width: 110)
                    }

                    // ── Stat tiles ──────────────────────────────────────────
                    HStack(spacing: 12) {
                        StatTile(
                            label: "LAST DRINK",
                            value: recentDrinks.first?.name ?? "—",
                            subtitle: recentDrinks.first.map {
                                $0.timestamp.formatted(date: .omitted, time: .shortened)
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

                    // ── Safety footer ───────────────────────────────────────
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
    }

    private func countdownLabel(_ date: Date) -> String {
        let secs = date.timeIntervalSince(.now)
        guard secs > 0 else { return "Clearing now" }
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        return h > 0 ? "in \(h)h \(m)m" : "in \(m)m"
    }
}
