import SwiftUI

struct DrinkTypeCard: View {
    let preset: PresetDrink
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Color.accentAmber.opacity(0.18) : Color.cardBackgroundSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? Color.accentAmber : Color.clear, lineWidth: 1.5)
                        )
                    Text(preset.category.icon)
                        .font(.system(size: 30))
                }
                .frame(height: 64)

                Text(preset.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .accentAmber : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("\(Int(preset.volumeML))mL · \(Int(preset.abv * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}
