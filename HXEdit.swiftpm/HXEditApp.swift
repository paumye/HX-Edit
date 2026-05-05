import SwiftUI

@main
struct HXEditApp: App {
    @StateObject private var midi = MIDIController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(midi)
        }
    }
}
