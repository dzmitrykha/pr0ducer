import AppIntents

public struct StopActivityIntent: AppIntent {
  public static let title: LocalizedStringResource = "Stop Activity"
  public static let description = IntentDescription(
    "Stops the activity currently in progress."
  )
  public static let openAppWhenRun = false

  public init() {}

  public func perform() async throws -> some IntentResult {
    try await IntentRuntime.performStop()
    return .result()
  }
}
