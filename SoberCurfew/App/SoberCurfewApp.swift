import SwiftUI
import SwiftData

@main
struct SoberCurfewApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([DrinkEntry.self, UserProfile.self])
        // CloudKit sync enabled — remove cloudKitDatabase parameter for local-only builds
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData ModelContainer failed to initialize: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
