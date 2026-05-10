import SwiftUI
import SwiftData

struct WatchView: View {
    @Query(sort: \DrinkEntry.timestamp, order: .reverse) private var allDrinks: [DrinkEntry]
    @Query private var profiles: [UserProfile]
    @State private var metabolism = MetabolismManager()
    @State private var pulseOpacity: Double = 1.0

    private var profile: UserProfile { profiles.first ?? UserProfile() }

    private var recentDrinks: [DrinkEntry] {
        allDrinks.filter { $0.effectiveTimestamp > Date().addingTimeInterval(-12 * 3600) }
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

    private var isAbsorbing: Bool {
        metabolism.isAbsorbing(drinks: recentDrinks)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.accentAmber, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: progress)
                        .opacity(isAbsorbing ? pulseOpacity : 1.0)
                }
                .frame(width: 56, height: 56)

                Text(bac.bacFormatted)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(bac > 0 ? .accentAmber : .sleepGreen)

                if isAbsorbing {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 10))
                        Text("RISING")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.0)
                    }
                    .foregroundColor(.accentAmber)
                }

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
        .onAppear { updatePulse() }
        .onChange(of: isAbsorbing) { updatePulse() }
    }

    private func updatePulse() {
        if isAbsorbing {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.45
            }
        } else {
            withAnimation(.default) { pulseOpacity = 1.0 }
        }
    }
}
