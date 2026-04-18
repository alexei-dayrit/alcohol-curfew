import Foundation
import SwiftData

enum BiologicalSex: String, Codable, CaseIterable {
    case male   = "Male"
    case female = "Female"

    var widmarkR: Double {
        switch self {
        case .male:   return 0.68
        case .female: return 0.55
        }
    }
}

enum BodyComposition: String, Codable, CaseIterable {
    case athletic  = "Athletic"
    case average   = "Average"
    case sedentary = "Sedentary"

    var tbwModifier: Double {
        switch self {
        case .athletic:  return 1.05
        case .average:   return 1.0
        case .sedentary: return 0.95
        }
    }
}

enum ToleranceLevel: String, Codable, CaseIterable {
    case standard = "Standard"
    case moderate = "Moderate"
    case high     = "High"

    // g/dL per hour
    var eliminationRate: Double {
        switch self {
        case .standard: return 0.015
        case .moderate: return 0.017
        case .high:     return 0.020
        }
    }
}

enum FoodState: String, Codable, CaseIterable {
    case empty = "Empty"
    case light = "Light"
    case full  = "Full"

    // Absorption window in hours
    var absorptionHours: Double {
        switch self {
        case .empty: return 0.50   // 30 min
        case .light: return 0.75   // 45 min
        case .full:  return 1.25   // 75 min
        }
    }

    var icon: String {
        switch self {
        case .empty: return "🍃"
        case .light: return "🥗"
        case .full:  return "🍽️"
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

    // Ultra calibration fields — optional; Watson formula used when both present
    var heightCm: Double
    var age: Int
    var bodyComposition: BodyComposition
    var toleranceLevel: ToleranceLevel
    var sessionFoodState: FoodState

    init(
        weightKg: Double = 79.4,
        biologicalSex: BiologicalSex = .male,
        bedtimeHour: Int = 23,
        bedtimeMinute: Int = 0,
        hasAcceptedDisclaimer: Bool = false,
        healthKitEnabled: Bool = false,
        heightCm: Double = 0,
        age: Int = 0,
        bodyComposition: BodyComposition = .average,
        toleranceLevel: ToleranceLevel = .standard,
        sessionFoodState: FoodState = .light
    ) {
        self.weightKg = weightKg
        self.biologicalSex = biologicalSex
        self.bedtimeHour = bedtimeHour
        self.bedtimeMinute = bedtimeMinute
        self.hasAcceptedDisclaimer = hasAcceptedDisclaimer
        self.healthKitEnabled = healthKitEnabled
        self.heightCm = heightCm
        self.age = age
        self.bodyComposition = bodyComposition
        self.toleranceLevel = toleranceLevel
        self.sessionFoodState = sessionFoodState
    }

    var weightLbs: Double {
        get { weightKg * 2.20462 }
        set { weightKg = newValue / 2.20462 }
    }

    // Watson Total Body Water (litres). Returns nil if height/age not provided.
    var watsonTBW: Double? {
        guard heightCm > 0, age > 0 else { return nil }
        let tbw: Double
        switch biologicalSex {
        case .male:
            tbw = 2.447 - (0.09516 * Double(age)) + (0.1074 * heightCm) + (0.3362 * weightKg)
        case .female:
            tbw = -2.097 + (0.1069 * heightCm) + (0.2466 * weightKg)
        }
        return max(1, tbw * bodyComposition.tbwModifier)
    }

    // Volume of distribution in grams — used in BAC denominator
    var volumeOfDistribution: Double {
        if let tbw = watsonTBW {
            return tbw * 1000.0   // litres → grams
        }
        return weightKg * 1000.0 * biologicalSex.widmarkR
    }

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
