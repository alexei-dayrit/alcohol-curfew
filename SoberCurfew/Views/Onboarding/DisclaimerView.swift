import SwiftUI
import SwiftData

struct DisclaimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var hasAccepted: Bool

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.accentAmber.opacity(0.12))
                            .frame(width: 110, height: 110)
                        Circle()
                            .stroke(Color.accentAmber.opacity(0.25), lineWidth: 1.5)
                            .frame(width: 110, height: 110)
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 50))
                            .foregroundColor(.accentAmber)
                    }

                    Text("SoberCurfew")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Predictive metabolic tracking\nto reclaim tomorrow morning.")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Disclaimer card
                BentoCard(padding: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.sleepYellow)
                                .font(.system(size: 18))
                            Text("SAFETY DISCLAIMER")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.sleepYellow)
                                .tracking(1.5)
                        }

                        Text("SoberCurfew provides **estimates only** based on the Widmark formula. Individual metabolism varies significantly based on food intake, medications, hydration, tolerance, and other factors.")
                            .font(.system(size: 14))
                            .foregroundColor(.white)

                        Text("**Never drive, operate heavy machinery, or make safety-critical decisions based on this app.**")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.sleepRed)
                    }
                }
                .padding(.bottom, 20)

                // CTA
                Button(action: accept) {
                    Text("I Understand — Let's Go")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.accentAmber)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)

                Text("By continuing you agree to use this app responsibly.")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
    }

    private func accept() {
        if let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first {
            profile.hasAcceptedDisclaimer = true
        } else {
            let profile = UserProfile()
            profile.hasAcceptedDisclaimer = true
            modelContext.insert(profile)
        }
        hasAccepted = true
    }
}
