import SwiftUI
import SwiftData

struct SleepCurfewView: View {
    @Query(sort: \DrinkEntry.timestamp, order: .reverse) private var allDrinks: [DrinkEntry]
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @State private var metabolism = MetabolismManager()

    private var profile: UserProfile { profiles.first ?? UserProfile() }

    private var recentDrinks: [DrinkEntry] {
        allDrinks.filter { $0.effectiveTimestamp > Date().addingTimeInterval(-12 * 3600) }
    }

    private var currentBAC: Double {
        metabolism.currentBAC(drinks: recentDrinks, profile: profile)
    }

    private var soberTime: Date? {
        metabolism.timeToZero(drinks: recentDrinks, profile: profile)
    }

    private var impact: SleepImpact {
        metabolism.sleepImpact(drinks: recentDrinks, profile: profile, bedtime: profile.bedtimeDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusCard
                timelineCard
                zonesLegend
                disclaimerFooter
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Sleep Curfew")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private var statusCard: some View {
        BentoCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("METABOLIC CURFEW")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .tracking(1.5)

                Text("Prediction of sleep impact based on your metabolism and bedtime.")
                    .font(.system(size: 14))
                    .foregroundColor(.white)

                impactBadge
            }
        }
    }

    private var impactBadge: some View {
        let color: Color = switch impact {
            case .optimal:   .sleepGreen
            case .reduced:   .sleepYellow
            case .disrupted: .sleepRed
        }
        return HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .shadow(color: color.opacity(0.9), radius: 5)
            Text(impact.label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
            Spacer()
            if let soberTime {
                Text("Sober \(soberTime.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var timelineCard: some View {
        if recentDrinks.isEmpty {
            BentoCard {
                VStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.accentBlue.opacity(0.5))
                    Text("No drinks logged")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Log a drink to see your sleep impact prediction.")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        } else {
            BentoCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("METABOLIZATION TIMELINE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .tracking(1.5)

                    MetabolicTimelineBar(
                        soberTime: soberTime,
                        bedtime: profile.bedtimeDate,
                        impact: impact
                    )
                }
            }
        }
    }

    private var zonesLegend: some View {
        BentoCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("SLEEP ZONES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .tracking(1.5)

                ZoneRow(color: .sleepGreen,  title: "Restorative Sleep Optimal",
                        detail: "BAC clears before bedtime, REM cycles intact")
                Divider().background(Color.white.opacity(0.07))
                ZoneRow(color: .sleepYellow, title: "Reduced Sleep Quality",
                        detail: "Trace alcohol suppresses REM and deep sleep")
                Divider().background(Color.white.opacity(0.07))
                ZoneRow(color: .sleepRed,    title: "Curfew Warning",
                        detail: "Significant BAC at bedtime — disrupted sleep expected")
            }
        }
    }

    private var disclaimerFooter: some View {
        Text("ESTIMATES ONLY · NEVER DRIVE UNDER THE INFLUENCE")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.textSecondary.opacity(0.4))
            .tracking(1)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
}

// MARK: - Supporting views

private struct ZoneRow: View {
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
        }
    }
}

private struct MetabolicTimelineBar: View {
    let soberTime: Date?
    let bedtime: Date
    let impact: SleepImpact

    var body: some View {
        let now = Date()
        let end = max(bedtime, soberTime ?? bedtime).addingTimeInterval(3600)
        let total = end.timeIntervalSince(now)

        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.cardBackgroundSecondary)
                        .frame(height: 10)

                    // Active alcohol window
                    if let soberTime, soberTime > now {
                        let fraction = min(1.0, soberTime.timeIntervalSince(now) / total)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                colors: [.accentAmber, .accentAmber.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * fraction, height: 10)
                    }

                    // Bedtime marker
                    let bedFraction = min(1.0, bedtime.timeIntervalSince(now) / total)
                    Rectangle()
                        .fill(Color.accentBlue)
                        .frame(width: 2, height: 18)
                        .offset(x: geo.size.width * bedFraction - 1, y: -4)
                }
                .frame(height: 10)
            }
            .frame(height: 18)

            HStack {
                timeLabel("Now", color: .textSecondary)
                Spacer()
                if let soberTime {
                    timeLabel(soberTime.formatted(date: .omitted, time: .shortened), color: .accentAmber, sub: "Sober")
                }
                Spacer()
                timeLabel(bedtime.formatted(date: .omitted, time: .shortened), color: .accentBlue, sub: "Bedtime")
            }
        }
    }

    @ViewBuilder
    private func timeLabel(_ value: String, color: Color, sub: String? = nil) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            if let sub {
                Text(sub)
                    .font(.system(size: 9))
                    .foregroundColor(.textSecondary)
            }
        }
    }
}
