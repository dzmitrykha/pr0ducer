import ActivityIntents
import ActivityWidgetUI
import SwiftUI
import WidgetKit

struct ToggleActivityComplication: Widget {
  let kind = "ToggleActivity"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ActivitySnapshotProvider()) { entry in
      ToggleActivityComplicationView(entry: entry)
    }
    .configurationDisplayName("Toggle Activity")
    .description("Tap to start or stop an activity without opening the app.")
    .supportedFamilies([.accessoryCircular])
  }
}

private struct ToggleActivityComplicationView: View {
  let entry: ActivitySnapshotEntry

  var body: some View {
    Button(intent: ToggleActivityIntent()) {
      ActivityRingView(snapshot: entry.snapshot)
    }
    .buttonStyle(.plain)
    .containerBackground(.fill.tertiary, for: .widget)
  }
}
