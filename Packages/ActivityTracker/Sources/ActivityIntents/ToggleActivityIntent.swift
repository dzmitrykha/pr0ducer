import AppIntents

public struct ToggleActivityIntent: AppIntent {
  public static let title: LocalizedStringResource = "Toggle Activity"
  public static let description = IntentDescription(
    "Starts a new activity or stops the one in progress."
  )
  public static let openAppWhenRun = false

  public init() {}

  public func perform() async throws -> some IntentResult {
    try await IntentRuntime.performToggle()
    return .result()
  }
}
