import SwiftUI
import SwiftData

@main
struct SoberCurfewWatchApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([DrinkEntry.self, UserProfile.self])
        // Local-only on Watch — CloudKit syncs the data from the paired iPhone
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Watch ModelContainer failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchView()
        }
        .modelContainer(container)
    }
}
