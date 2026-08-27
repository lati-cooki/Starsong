import SwiftUI

@main
struct StarsongApp: App {
    var body: some Scene {
        WindowGroup {
            // Which app this is comes from `Keepsake.opensOnLaunch` — one line
            // in `Sources/Fifty/Keepsake.swift`. Left as Starsong by default so
            // the tests, which go looking for the night sky, still find it.
            Group {
                if Keepsake.opensOnLaunch {
                    KeepsakeView()
                } else {
                    ContentView()
                }
            }
            .preferredColorScheme(.dark)
            .persistentSystemOverlays(.hidden)
        }
    }
}
