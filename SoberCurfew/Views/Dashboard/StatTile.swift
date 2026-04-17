import SwiftUI

struct StatTile: View {
    let label: String
    let value: String
    let subtitle: String?

    init(label: String, value: String, subtitle: String? = nil) {
        self.label = label
        self.value = value
        self.subtitle = subtitle
    }

    var body: some View {
        BentoCard(padding: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .tracking(1.5)
                    .lineLimit(1)

                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
