import SwiftUI

@main
struct HomeTrackApp: App {
    @StateObject private var store = Store()
    @StateObject private var tracker = TimeTracker()

    var body: some Scene {
        WindowGroup("HomeTrack", id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(tracker)
                .preferredColorScheme(store.scheme)
                .frame(minWidth: 1000, minHeight: 700)
                .onAppear { tracker.start() }
        }
    }
}
