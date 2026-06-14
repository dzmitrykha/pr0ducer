import Foundation

public enum AppGroup {
  /// App Group identifier — must match entitlements on app and widget targets.
  public static let identifier = "group.dev.pr0ducer.activitytracker"

  public static var containerURL: URL {
    guard let url = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: identifier
    ) else {
      fatalError("App Group container unavailable: \(identifier)")
    }
    return url
  }

  public static var databaseURL: URL {
    containerURL.appendingPathComponent("activitytracker.sqlite")
  }
}
