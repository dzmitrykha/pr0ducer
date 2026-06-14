import AppFeature
import ComposableArchitecture
import Dependencies
import SwiftUI
#if targetEnvironment(simulator)
import Database
#endif

@main
struct ActivityTrackerApp: App {
  @Environment(\.scenePhase) private var scenePhase

  private let store: StoreOf<AppFeature>

  init() {
    prepareDependencies {
      $0.activityDatabase = .liveValue
    }
    store = Store(initialState: AppFeature.State()) {
      #if DEBUG
        AppFeature.debug()
      #else
        AppFeature()
      #endif
    }
  }

  var body: some Scene {
    WindowGroup {
      AppView(store: store)
        .task {
          #if targetEnvironment(simulator)
          try? await SimulatorSeedData.seedIfNeeded()
          store.send(.dayList(.refresh))
          #endif
        }
        .onOpenURL { url in
          store.send(.deepLink(url))
        }
        .onChange(of: scenePhase) { _, newPhase in
          store.send(.scenePhaseChanged(newPhase))
        }
    }
  }
}
