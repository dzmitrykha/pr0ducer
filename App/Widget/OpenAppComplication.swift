import ActivityWidgetUI
import Shared
import SwiftUI
import WidgetKit

struct OpenAppComplication: Widget {
  let kind = "OpenApp"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ActivitySnapshotProvider()) { entry in
      OpenAppComplicationView(entry: entry)
    }
    .configurationDisplayName(L10n.widgetOpenDisplayName)
    .description(L10n.widgetOpenDescription)
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
