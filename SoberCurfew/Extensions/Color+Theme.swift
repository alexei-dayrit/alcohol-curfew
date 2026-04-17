import SwiftUI

extension Color {
    static let appBackground          = Color(hex: "0A0A0F")
    static let cardBackground         = Color(hex: "141420")
    static let cardBackgroundSecondary = Color(hex: "1C1C2E")
    static let accentAmber            = Color(hex: "F5A623")
    static let accentBlue             = Color(hex: "4FC3F7")
    static let sleepGreen             = Color(hex: "30D158")
    static let sleepYellow            = Color(hex: "FFD60A")
    static let sleepRed               = Color(hex: "FF453A")
    static let textPrimary            = Color.white
    static let textSecondary          = Color(hex: "8E8EA0")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
