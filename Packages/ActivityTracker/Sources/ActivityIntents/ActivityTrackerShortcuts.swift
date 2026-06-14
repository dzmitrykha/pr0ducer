import AppIntents

struct ActivityTrackerShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: ToggleActivityIntent(),
      phrases: [
        "Toggle activity in \(.applicationName)",
        "Start or stop activity in \(.applicationName)",
      ],
      shortTitle: "Toggle Activity",
      systemImageName: "circle.fill"
    )
    AppShortcut(
      intent: StartActivityIntent(),
      phrases: ["Start activity in \(.applicationName)"],
      shortTitle: "Start Activity",
      systemImageName: "play.fill"
    )
    AppShortcut(
      intent: StopActivityIntent(),
      phrases: ["Stop activity in \(.applicationName)"],
      shortTitle: "Stop Activity",
      systemImageName: "stop.fill"
    )
    AppShortcut(
      intent: StartActivityWithConfirmationIntent(),
      phrases: ["Start activity with confirmation in \(.applicationName)"],
      shortTitle: "Start (Confirm)",
      systemImageName: "play.circle"
    )
    AppShortcut(
      intent: StopActivityWithConfirmationIntent(),
      phrases: ["Stop activity with confirmation in \(.applicationName)"],
      shortTitle: "Stop (Confirm)",
      systemImageName: "stop.circle"
    )
  }
}
