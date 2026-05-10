import Foundation
import HealthKit
import Observation

@MainActor
@Observable
final class HealthKitManager {
    var isAuthorized = false
    var errorMessage: String?

    private let store = HKHealthStore()
    private var lastWrittenBAC: Double = -1
    private var lastWriteDate: Date = .distantPast

    private var bacQuantityType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .bloodAlcoholContent)
    }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let sex = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            types.insert(sex)
        }
        if let weight = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weight)
        }
        return types
    }

    private var writeTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        if let bac = bacQuantityType {
            types.insert(bac)
        }
        return types
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device."
            return
        }
        guard let bacType = bacQuantityType else { return }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = store.authorizationStatus(for: bacType) == .sharingAuthorized
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchBiologicalSex() -> BiologicalSex? {
        guard let sex = try? store.biologicalSex() else { return nil }
        switch sex.biologicalSex {
        case .male:   return .male
        case .female: return .female
        default:      return nil
        }
    }

    func fetchLatestWeightKg() async -> Double? {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return nil }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }

    func writeBACSample(_ bac: Double, date: Date = .now) async {
        guard isAuthorized else { return }
        guard bac > 0 else { return }
        guard abs(bac - lastWrittenBAC) > 0.002 || date.timeIntervalSince(lastWriteDate) >= 300 else { return }
        guard let bacType = bacQuantityType else { return }
        let quantity = HKQuantity(unit: .percent(), doubleValue: bac)
        let sample = HKQuantitySample(type: bacType, quantity: quantity, start: date, end: date)
        try? await store.save(sample)
        lastWrittenBAC = bac
        lastWriteDate = date
    }
}
