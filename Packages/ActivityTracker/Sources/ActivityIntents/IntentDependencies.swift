import Dependencies
import Database
import Foundation

/// Installs live dependencies for App Intent and widget extension processes.
///
/// App Intents run in the widget extension (or Shortcuts) without the app's
/// `prepareDependencies` call, so they must bootstrap the App Group database here.
public enum IntentDependencies {
  private final class BootstrapState: @unchecked Sendable {
    let lock = NSLock()
    var isPrepared = false
  }

  private static let state = BootstrapState()

  /// Safe to call repeatedly; runs once per process.
  public static func bootstrap() {
    state.lock.lock()
    defer { state.lock.unlock() }
    guard !state.isPrepared else { return }
    prepareDependencies {
      $0.activityDatabase = .liveValue
    }
    state.isPrepared = true
  }
}
