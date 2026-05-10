import Foundation
import Observation

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

    // MARK: - Core BAC

    /// Current estimated BAC using a two-phase piecewise model per drink:
    /// rising linearly over the absorption window, then decaying at the elimination rate.
    func currentBAC(drinks: [DrinkEntry], profile: UserProfile) -> Double {
        max(0, drinks.reduce(0.0) { $0 + contribution(of: $1, at: .now, profile: profile) })
    }

    /// True while any logged drink is still within its absorption window (BAC still rising).
    func isAbsorbing(drinks: [DrinkEntry]) -> Bool {
        let now = Date()
        return drinks.contains { drink in
            let t = now.timeIntervalSince(drink.effectiveTimestamp) / 3600.0
            return t >= 0 && t < drink.absorptionHours
        }
    }

    // MARK: - ZeroLine

    /// Scans forward in 5-minute steps to find when total BAC drops to zero.
    func timeToZero(drinks: [DrinkEntry], profile: UserProfile) -> Date? {
        guard currentBAC(drinks: drinks, profile: profile) > 0 else { return nil }
        let step: TimeInterval = 300
        var probe = Date()
        for _ in 0..<(48 * 12) {
            probe = probe.addingTimeInterval(step)
            if bacAt(date: probe, drinks: drinks, profile: profile) <= 0 { return probe }
        }
        return nil
    }

    // MARK: - UI Helpers

    /// Fraction of theoretical peak BAC currently in the blood (0.0–1.0).
    func bacProgress(drinks: [DrinkEntry], profile: UserProfile) -> Double {
        let current = currentBAC(drinks: drinks, profile: profile)
        let peak = peakBAC(drinks: drinks, profile: profile)
        guard peak > 0 else { return 0 }
        return min(1.0, current / peak)
    }

    func sleepImpact(drinks: [DrinkEntry], profile: UserProfile, bedtime: Date) -> SleepImpact {
        guard let soberTime = timeToZero(drinks: drinks, profile: profile) else { return .optimal }
        if soberTime > bedtime { return .disrupted }
        let bacAtBed = bacAt(date: bedtime, drinks: drinks, profile: profile)
        return bacAtBed >= 0.04 ? .reduced : .optimal
    }

    // MARK: - Private

    private func contribution(of drink: DrinkEntry, at date: Date, profile: UserProfile) -> Double {
        let t = date.timeIntervalSince(drink.effectiveTimestamp) / 3600.0
        guard t >= 0 else { return 0 }
        let peak = (drink.alcoholGrams / profile.volumeOfDistribution) * 100.0
        let tAbs = drink.absorptionHours
        let beta = profile.toleranceLevel.eliminationRate
        if t < tAbs {
            return peak * (t / tAbs)                   // absorption phase — rising
        } else {
            return max(0, peak - beta * (t - tAbs))    // elimination phase — falling
        }
    }

    private func bacAt(date: Date, drinks: [DrinkEntry], profile: UserProfile) -> Double {
        max(0, drinks.reduce(0.0) { $0 + contribution(of: $1, at: date, profile: profile) })
    }

    // True peak — scan forward in 5-minute steps from first drink to find highest combined BAC.
    private func peakBAC(drinks: [DrinkEntry], profile: UserProfile) -> Double {
        guard let start = drinks.map(\.effectiveTimestamp).min() else { return 0 }
        let step: TimeInterval = 300
        var peak = 0.0
        var probe = start
        for _ in 0..<(48 * 12) {
            let bac = bacAt(date: probe, drinks: drinks, profile: profile)
            if bac > peak { peak = bac }
            probe = probe.addingTimeInterval(step)
            if bac <= 0 && probe > Date() { break }
        }
        return peak
    }
}
