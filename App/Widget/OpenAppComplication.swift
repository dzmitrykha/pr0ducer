import ActivityWidgetUI
import SwiftUI
import WidgetKit

struct OpenAppComplication: Widget {
  let kind = "OpenApp"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ActivitySnapshotProvider()) { entry in
      OpenAppComplicationView(entry: entry)
    }
    .configurationDisplayName("Open Activity Tracker")
    .description("Tap to open the app and view your activity history.")
    .supportedFamilies([.accessoryCircular])
  }
}

private struct OpenAppComplicationView: View {
  let entry: ActivitySnapshotEntry

  var body: some View {
    OpenAppRingView(snapshot: entry.snapshot)
      .widgetURL(URL(string: "activitytracker://open")!)
      .containerBackground(.fill.tertiary, for: .widget)
  }
}
