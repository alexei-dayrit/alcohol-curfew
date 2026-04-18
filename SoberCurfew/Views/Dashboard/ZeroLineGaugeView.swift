import SwiftUI

private let legalLimits: [(bac: Double, color: Color, label: String)] = [
    (0.05, .sleepYellow, "0.05"),
    (0.08, .sleepRed,    "0.08"),
]

struct ZeroLineGaugeView: View {
    let bac: Double
    let progress: Double      // 0.0–1.0, fraction of peak BAC remaining
    let soberTime: Date?
    let isAbsorbing: Bool

    // The gauge ring is scaled relative to peak BAC.
    // To draw legal limit ticks at absolute BAC values we need peakBAC.
    // peakBAC = bac / progress when progress > 0; otherwise no ticks needed.
    private var peakBAC: Double {
        progress > 0 ? bac / progress : 0
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 14)
                .padding(14)

            // Progress ring — color shifts to red while absorbing
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: isAbsorbing
                            ? [.sleepRed, .accentAmber.opacity(0.6)]
                            : [.accentAmber, .accentAmber.opacity(0.5)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.2), value: progress)
                .animation(.easeInOut(duration: 0.3), value: isAbsorbing)
                .padding(14)

            // Legal limit tick marks
            if peakBAC > 0 {
                GeometryReader { geo in
                    let radius = (min(geo.size.width, geo.size.height) / 2) - 14
                    ForEach(legalLimits, id: \.bac) { limit in
                        let fraction = min(1.0, limit.bac / peakBAC)
                        let angle = Angle.degrees(-90 + fraction * 360)
                        limitTick(radius: radius, angle: angle, color: limit.color, geo: geo)
                    }
                }
            }

            // Glow dot at progress tip
            if progress > 0 {
                GeometryReader { geo in
                    let radius = (min(geo.size.width, geo.size.height) / 2) - 14
                    Circle()
                        .fill(isAbsorbing ? Color.sleepRed : Color.accentAmber)
                        .frame(width: 12, height: 12)
                        .shadow(color: isAbsorbing ? .sleepRed : .accentAmber, radius: 8)
                        .offset(y: -radius)
                        .rotationEffect(.degrees(-90 + progress * 360))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .animation(.easeInOut(duration: 0.3), value: isAbsorbing)
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
                        .foregroundColor(isAbsorbing ? .sleepRed : .accentAmber)
                } else {
                    Text("Clear")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.sleepGreen)
                }

                Text(isAbsorbing ? "Absorbing · still rising" : (bac > 0 ? "BAC · Estimated" : "No alcohol detected"))
                    .font(.system(size: 11))
                    .foregroundColor(isAbsorbing ? .sleepRed.opacity(0.8) : .textSecondary)
                    .animation(.easeInOut(duration: 0.3), value: isAbsorbing)
            }
        }
    }

    @ViewBuilder
    private func limitTick(radius: Double, angle: Angle, color: Color, geo: GeometryProxy) -> some View {
        let cx = geo.size.width / 2
        let cy = geo.size.height / 2
        let radians = angle.radians
        let x = cx + radius * cos(radians)
        let y = cy + radius * sin(radians)
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .position(x: x, y: y)
            .shadow(color: color.opacity(0.8), radius: 3)
    }
}
