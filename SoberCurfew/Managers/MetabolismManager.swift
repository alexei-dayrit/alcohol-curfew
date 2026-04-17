import Foundation
import Observation

/// BAC impact on sleep quality relative to bedtime
enum SleepImpact {
    case optimal    // sober well before bed, BAC < 0.04%
    case reduced    // sober before bed but low trace alcohol
    case disrupted  // still positive BAC at bedtime

    var label: String {
        switch self {
        case .optimal:   return "Restorative Sleep Optimal"
        case .reduced:   return "Reduced Sleep Quality"
        case .disrupted: return "Curfew Warning"
        }
    }

    var description: String {
        switch self {
        case .optimal:   return "BAC clears well before bedtime. Sleep quality unaffected."
        case .reduced:   return "Trace alcohol may affect REM cycles. Consider delaying bedtime slightly."
        case .disrupted: return "BAC extends past your bedtime. Significant REM disruption expected."
        }
    }
}

@Observable
final class MetabolismManager {
    // Standard Widmark elimination rate: 0.015 g/dL per hour
    private let eliminationRate: Double = 0.015

    // MARK: - Core BAC Calculation

    /// Current estimated BAC using per-drink Widmark contributions
    func currentBAC(drinks: [DrinkEntry], profile: UserProfile) -> Double {
        let now = Date()
        let weightGrams = profile.weightKg * 1000.0
        let r = profile.biologicalSex.widmarkR

        let total = drinks.reduce(0.0) { sum, drink in
            let hours = now.timeIntervalSince(drink.timestamp) / 3600.0
            guard hours >= 0 else { return sum }
            // Widmark: BAC% = (A / (W × r)) × 100 − β × t
            let raw = (drink.alcoholGrams / (weightGrams * r)) * 100.0
            return sum + max(0, raw - eliminationRate * hours)
        }

        return max(0, total)
    }

    /// Time when BAC will reach 0.00% given current elimination trajectory
    func timeToZero(drinks: [DrinkEntry], profile: UserProfile) -> Date? {
        let bac = currentBAC(drinks: drinks, profile: profile)
        guard bac > 0 else { return nil }
        let hoursRemaining = bac / eliminationRate
        return Date().addingTimeInterval(hoursRemaining * 3600)
    }

    // MARK: - UI Helpers

    /// Fraction of peak BAC remaining (0.0–1.0) — drives the gauge ring progress
    func bacProgress(drinks: [DrinkEntry], profile: UserProfile) -> Double {
        let current = currentBAC(drinks: drinks, profile: profile)
        let peak = peakBAC(drinks: drinks, profile: profile)
        guard peak > 0 else { return 0 }
        return min(1.0, current / peak)
    }

    /// Predicted impact on sleep quality based on sobering window vs. bedtime
    func sleepImpact(drinks: [DrinkEntry], profile: UserProfile, bedtime: Date) -> SleepImpact {
        guard let soberTime = timeToZero(drinks: drinks, profile: profile) else {
            return .optimal
        }
        let bac = currentBAC(drinks: drinks, profile: profile)
        if soberTime > bedtime {
            return .disrupted
        } else if bac >= 0.04 {
            return .reduced
        } else {
            return .optimal
        }
    }

    // MARK: - Private

    // Sum of all individual drink BAC contributions without elimination — represents theoretical peak
    private func peakBAC(drinks: [DrinkEntry], profile: UserProfile) -> Double {
        let weightGrams = profile.weightKg * 1000.0
        let r = profile.biologicalSex.widmarkR
        return drinks.reduce(0.0) { sum, drink in
            sum + (drink.alcoholGrams / (weightGrams * r)) * 100.0
        }
    }
}
