import WidgetKit
import SwiftUI
import SwiftData

private let appGroupID = "group.com.sobercurfew.app"

// MARK: - Timeline Entry

struct CurfewEntry: TimelineEntry {
    let date: Date
    let bac: Double
    let soberTime: Date?
    let impact: WidgetImpact

    enum WidgetImpact {
        case clear, optimal, reduced, disrupted

        var color: Color {
            switch self {
            case .clear:     return .sleepGreen
            case .optimal:   return .sleepGreen
            case .reduced:   return .sleepYellow
            case .disrupted: return .sleepRed
            }
        }

        static func from(key: String) -> WidgetImpact {
            switch key {
            case "optimal":   return .optimal
            case "reduced":   return .reduced
            case "disrupted": return .disrupted
            default:          return .clear
            }
        }
    }

    static let placeholder = CurfewEntry(
        date: .now,
        bac: 0.045,
        soberTime: Calendar.current.date(byAdding: .hour, value: 2, to: .now),
        impact: .reduced
    )

    static let clear = CurfewEntry(date: .now, bac: 0, soberTime: nil, impact: .clear)
}

// MARK: - Timeline Provider

struct CurfewProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurfewEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (CurfewEntry) -> Void) {
        completion(context.isPreview ? .placeholder : buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurfewEntry>) -> Void) {
        let entry = buildEntry()
        let nextUpdate = Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func buildEntry() -> CurfewEntry {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return .clear }
        let bac = defaults.double(forKey: "bac")
        let soberInterval = defaults.double(forKey: "soberTime")
        let soberTime = soberInterval > 0 ? Date(timeIntervalSince1970: soberInterval) : nil
        let impactKey = defaults.string(forKey: "impact") ?? "clear"
        let impact = CurfewEntry.WidgetImpact.from(key: impactKey)
        return CurfewEntry(date: .now, bac: bac, soberTime: soberTime, impact: impact)
    }
}

// MARK: - Widget Views

struct WidgetEntryView: View {
    let entry: CurfewEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            Color.appBackground

            switch family {
            case .systemSmall:  smallView
            case .systemMedium: mediumView
            default:            smallView
            }
        }
        .containerBackground(.black, for: .widget)
    }

    private var smallView: some View {
        VStack(spacing: 6) {
            Text("SoberCurfew")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.textSecondary)
                .tracking(1)

            Text(entry.bac.bacFormatted)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(entry.bac > 0 ? .accentAmber : .sleepGreen)

            if let soberTime = entry.soberTime {
                Text(soberTime.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text("ZeroLine")
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            } else {
                Text("CLEAR")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.sleepGreen)
            }
        }
    }

    private var mediumView: some View {
        HStack(spacing: 20) {
            smallView
            Divider().background(Color.white.opacity(0.1))
            VStack(alignment: .leading, spacing: 6) {
                Text("SLEEP IMPACT")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .tracking(1.2)

                Circle()
                    .fill(entry.impact.color)
                    .frame(width: 10, height: 10)
                    .shadow(color: entry.impact.color.opacity(0.8), radius: 4)

                if let soberTime = entry.soberTime {
                    Text("Sober by")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                    Text(soberTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("No alcohol\ndetected")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Widget Configuration

@main
struct SoberCurfewWidget: Widget {
    let kind = "SoberCurfewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurfewProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("SoberCurfew")
        .description("Current BAC estimate and ZeroLine countdown.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
