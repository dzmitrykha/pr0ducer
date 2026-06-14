import ActivityIntents
import ActivityWidgetUI
import Shared
import SwiftUI
import WidgetKit

struct ToggleActivityComplication: Widget {
  let kind = "ToggleActivity"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ActivitySnapshotProvider()) { entry in
      ToggleActivityComplicationView(entry: entry)
    }
    .configurationDisplayName(L10n.widgetToggleDisplayName)
    .description(L10n.widgetToggleDescription)
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
    .containerBackground(for: .widget) {}
  }
}
