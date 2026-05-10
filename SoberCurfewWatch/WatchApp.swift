import SwiftUI
import SwiftData

@main
struct SoberCurfewWatchApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([DrinkEntry.self, UserProfile.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
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
