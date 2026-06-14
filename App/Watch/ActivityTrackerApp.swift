import SwiftUI

@main
struct ActivityTrackerApp: App {
  var body: some Scene {
    WindowGroup {
      // TODO(phase 4): prepareDependencies + root TCA Store from AppFeature
      ContentView()
    }
  }
}

private struct ContentView: View {
  var body: some View {
    Text("Activity Tracker")
      .font(.headline)
  }
}
