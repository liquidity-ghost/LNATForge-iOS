import SwiftData
import SwiftUI

@main
struct LNATForgeApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [
            QuestionAttempt.self,
            MockSessionRecord.self,
            SavedOutline.self,
            CompletedCardRecord.self,
        ])
    }
}
