import Foundation
import SwiftData

enum DrinkCategory: String, Codable, CaseIterable {
    case beer     = "Beer"
    case wine     = "Wine"
    case spirits  = "Spirits"
    case custom   = "Custom"

    var icon: String {
        switch self {
        case .beer:    return "🍺"
        case .wine:    return "🍷"
        case .spirits: return "🥃"
        case .custom:  return "🥤"
        }
    }
}

struct PresetDrink: Identifiable {
    let id = UUID()
    let name: String
    let category: DrinkCategory
    let volumeML: Double
    let abv: Double

    static let all: [PresetDrink] = [
        PresetDrink(name: "Pint",        category: .beer,    volumeML: 473,  abv: 0.05),
        PresetDrink(name: "Bottle",      category: .beer,    volumeML: 355,  abv: 0.05),
        PresetDrink(name: "Craft Beer",  category: .beer,    volumeML: 355,  abv: 0.065),
        PresetDrink(name: "Glass Wine",  category: .wine,    volumeML: 150,  abv: 0.12),
        PresetDrink(name: "Shot",        category: .spirits, volumeML: 44,   abv: 0.40),
        PresetDrink(name: "Cocktail",    category: .spirits, volumeML: 200,  abv: 0.15),
    ]
}

@Model
final class DrinkEntry {
    var id: UUID
    var name: String
    var category: DrinkCategory
    var volumeML: Double
    var abv: Double               // 0.0–1.0 (e.g. 0.05 = 5%)
    var timestamp: Date
    var isCarbonated: Bool
    var timestampOffsetSec: Int   // seconds subtracted from timestamp (retroactive logging)
    var foodStateAtTime: FoodState

    init(
        name: String,
        category: DrinkCategory,
        volumeML: Double,
        abv: Double,
        timestamp: Date = .now,
        isCarbonated: Bool = false,
        timestampOffsetSec: Int = 0,
        foodStateAtTime: FoodState = .light
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.volumeML = volumeML
        self.abv = abv
        self.timestamp = timestamp
        self.isCarbonated = isCarbonated
        self.timestampOffsetSec = timestampOffsetSec
        self.foodStateAtTime = foodStateAtTime
    }

    // Actual moment of consumption, accounting for retroactive offset
    var effectiveTimestamp: Date {
        timestamp.addingTimeInterval(-Double(timestampOffsetSec))
    }

    // Absorption window in hours, adjusted for carbonation
    var absorptionHours: Double {
        let base = foodStateAtTime.absorptionHours
        return isCarbonated ? base * 0.75 : base
    }

    var alcoholGrams: Double {
        volumeML * abv * 0.789
    }

    var standardDrinks: Double {
        alcoholGrams / 14.0
    }
}
