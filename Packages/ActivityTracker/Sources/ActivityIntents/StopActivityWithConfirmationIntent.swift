import AppIntents
import Shared

/// Opens the app to a countdown confirmation before stopping the current activity.
public struct StopActivityWithConfirmationIntent: AppIntent {
  public static let title: LocalizedStringResource = "intent.stop.confirmation.title"
  public static let description = IntentDescription(
    "Opens the app and asks you to confirm before stopping the activity in progress."
  )
  public static let openAppWhenRun = true

  public init() {}

  public func perform() async throws -> some IntentResult {
    IntentRuntime.savePendingAction(.confirmStop)
    return .result()
  }
}
