import SwiftUI

@main
struct AnchorApp: App {
    @AppStorage("anchor_appearance") private var appearanceMode: String = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
        }
    }
}
