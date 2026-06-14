import AppIntents

public struct StartActivityIntent: AppIntent {
  public static let title: LocalizedStringResource = "intent.start.title"
  public static let description = IntentDescription(
    "Starts a new activity if none is in progress."
  )
  public static let openAppWhenRun = false

  public init() {}

  public func perform() async throws -> some IntentResult {
    try await IntentRuntime.performStart()
    return .result()
  }
}
