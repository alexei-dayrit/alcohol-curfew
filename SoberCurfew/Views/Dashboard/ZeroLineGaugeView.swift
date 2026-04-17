import SwiftUI

struct ZeroLineGaugeView: View {
    let bac: Double
    let progress: Double      // 0.0–1.0, fraction of peak BAC remaining
    let soberTime: Date?

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 14)
                .padding(14)

            // Progress ring — amber gradient, clockwise from top
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.accentAmber, .accentAmber.opacity(0.5)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.2), value: progress)
                .padding(14)

            // Glow dot at progress tip — positioned using GeometryReader radius
            if progress > 0 {
                GeometryReader { geo in
                    let radius = (min(geo.size.width, geo.size.height) / 2) - 14
                    Circle()
                        .fill(Color.accentAmber)
                        .frame(width: 12, height: 12)
                        .shadow(color: .accentAmber, radius: 8)
                        .offset(y: -radius)
                        .rotationEffect(.degrees(-90 + progress * 360))
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .animation(.easeInOut(duration: 1.2), value: progress)
            }

            // Center content
            VStack(spacing: 6) {
                Text("ZeroLine")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)

                Text(bac.bacFormatted)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: bac)

                if let soberTime {
                    Text(soberTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.accentAmber)
                } else {
                    Text("Clear")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.sleepGreen)
                }

                Text(bac > 0 ? "BAC · Estimated" : "No alcohol detected")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
        }
    }
}
