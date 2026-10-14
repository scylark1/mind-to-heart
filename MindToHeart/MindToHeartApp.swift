import SwiftUI
import SwiftData

@main
struct MindToHeartApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Thought.self)
    }
}
