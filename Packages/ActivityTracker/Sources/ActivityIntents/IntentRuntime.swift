import AppIntents
import Dependencies
import Database
import WidgetKit

enum IntentRuntime {
  static func reloadWidgetTimelines() {
    WidgetCenter.shared.reloadAllTimelines()
  }

  static func performToggle() async throws {
    IntentDependencies.bootstrap()
    @Dependency(\.date) var date
    @Dependency(\.activityDatabase) var database
    _ = try await database.toggle(date.now)
    reloadWidgetTimelines()
  }

  static func performStart() async throws {
    IntentDependencies.bootstrap()
    @Dependency(\.date) var date
    @Dependency(\.activityDatabase) var database
    _ = try await database.start(date.now)
    reloadWidgetTimelines()
  }

  static func performStop() async throws {
    IntentDependencies.bootstrap()
    @Dependency(\.date) var date
    @Dependency(\.activityDatabase) var database
    try await database.stop(date.now)
    reloadWidgetTimelines()
  }
}
