import SwiftUI

struct SleepImpactTile: View {
    let impact: SleepImpact
    let soberTime: Date?

    private var impactColor: Color {
        switch impact {
        case .optimal:   return .sleepGreen
        case .reduced:   return .sleepYellow
        case .disrupted: return .sleepRed
        }
    }

    var body: some View {
        BentoCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("SLEEP IMPACT")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .tracking(1.5)
                    Spacer()
                    Circle()
                        .fill(impactColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: impactColor.opacity(0.8), radius: 4)
                }

                Text(impact.label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(impactColor)

                Text(impact.description)
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let soberTime {
                    Divider()
                        .background(Color.white.opacity(0.08))
                    HStack(spacing: 4) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.accentBlue)
                        Text("Sober \(soberTime.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
    }
}
