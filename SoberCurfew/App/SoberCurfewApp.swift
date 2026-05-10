import SwiftUI
import SwiftData

@main
struct SoberCurfewApp: App {
    let container: ModelContainer
    @State private var healthKit = HealthKitManager()
    @State private var notifications = NotificationManager()

    init() {
        let schema = Schema([DrinkEntry.self, UserProfile.self])
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        if let cloudContainer = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
            container = cloudContainer
        } else {
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                container = try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("SwiftData ModelContainer failed to initialize: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthKit)
                .environment(notifications)
                .task { await notifications.requestAuthorization() }
        }
        .modelContainer(container)
    }
}
