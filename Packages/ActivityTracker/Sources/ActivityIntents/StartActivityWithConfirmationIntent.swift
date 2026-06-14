import AppIntents
import Shared

/// Opens the app to a countdown confirmation before starting an activity.
public struct StartActivityWithConfirmationIntent: AppIntent {
  public static let title: LocalizedStringResource = "intent.start.confirmation.title"
  public static let description = IntentDescription(
    "Opens the app and asks you to confirm before starting an activity."
  )
  public static let openAppWhenRun = true

  public init() {}

  public func perform() async throws -> some IntentResult {
    IntentRuntime.savePendingAction(.confirmStart)
    return .result()
  }
}
