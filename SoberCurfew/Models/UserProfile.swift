import Foundation
import SwiftData

enum BiologicalSex: String, Codable, CaseIterable {
    case male   = "Male"
    case female = "Female"

    // Widmark r factor — distributional volume of alcohol in body water
    var widmarkR: Double {
        switch self {
        case .male:   return 0.68
        case .female: return 0.55
        }
    }
}

@Model
final class UserProfile {
    var weightKg: Double
    var biologicalSex: BiologicalSex
    var bedtimeHour: Int
    var bedtimeMinute: Int
    var hasAcceptedDisclaimer: Bool
    var healthKitEnabled: Bool

    init(
        weightKg: Double = 79.4,
        biologicalSex: BiologicalSex = .male,
        bedtimeHour: Int = 23,
        bedtimeMinute: Int = 0,
        hasAcceptedDisclaimer: Bool = false,
        healthKitEnabled: Bool = false
    ) {
        self.weightKg = weightKg
        self.biologicalSex = biologicalSex
        self.bedtimeHour = bedtimeHour
        self.bedtimeMinute = bedtimeMinute
        self.hasAcceptedDisclaimer = hasAcceptedDisclaimer
        self.healthKitEnabled = healthKitEnabled
    }

    var weightLbs: Double {
        get { weightKg * 2.20462 }
        set { weightKg = newValue / 2.20462 }
    }

    // Next occurrence of the user's bedtime as an absolute Date
    var bedtimeDate: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = bedtimeHour
        components.minute = bedtimeMinute
        components.second = 0
        var date = Calendar.current.date(from: components) ?? .now
        if date < .now {
            date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }
}
