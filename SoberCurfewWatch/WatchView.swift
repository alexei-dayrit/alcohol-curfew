import SwiftUI
import SwiftData

struct WatchView: View {
    @Query(sort: \DrinkEntry.timestamp, order: .reverse) private var allDrinks: [DrinkEntry]
    @Query private var profiles: [UserProfile]
    @State private var metabolism = MetabolismManager()

    private var profile: UserProfile { profiles.first ?? UserProfile() }

    private var recentDrinks: [DrinkEntry] {
        allDrinks.filter { $0.timestamp > Date().addingTimeInterval(-12 * 3600) }
    }

    private var bac: Double {
        metabolism.currentBAC(drinks: recentDrinks, profile: profile)
    }

    private var soberTime: Date? {
        metabolism.timeToZero(drinks: recentDrinks, profile: profile)
    }

    private var progress: Double {
        metabolism.bacProgress(drinks: recentDrinks, profile: profile)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 6) {
                // Mini ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.accentAmber, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: progress)
                }
                .frame(width: 56, height: 56)

                Text(bac.bacFormatted)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(bac > 0 ? .accentAmber : .sleepGreen)

                if let soberTime {
                    Text(soberTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("ZeroLine")
                        .font(.system(size: 10))
                        .foregroundColor(.textSecondary)
                } else {
                    Text("CLEAR")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.sleepGreen)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
