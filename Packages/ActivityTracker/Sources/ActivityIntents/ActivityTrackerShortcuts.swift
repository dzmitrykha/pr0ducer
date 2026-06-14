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
  }
}
