import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    // Driven by the disclaimer acceptance in SwiftData
    private var disclaimerAccepted: Bool {
        profiles.first?.hasAcceptedDisclaimer ?? false
    }

    // Local toggle so DisclaimerView can immediately unlock the dashboard
    @State private var accepted = false

    var body: some View {
        if disclaimerAccepted || accepted {
            DashboardView()
        } else {
            DisclaimerView(hasAccepted: $accepted)
        }
    }
}
