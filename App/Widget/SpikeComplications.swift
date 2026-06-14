import ActivityIntents
import Dependencies
import Shared
import SwiftUI
import WidgetKit

/// Phase 2 spike — interactive toggle via `Button(intent:)`.
struct SpikeToggleComplication: Widget {
  let kind = "SpikeToggle"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SpikeTimelineProvider()) { entry in
      SpikeToggleView(entry: entry)
    }
    .configurationDisplayName("Toggle (Spike)")
    .description("Tap to start or stop an activity without opening the app.")
    .supportedFamilies([.accessoryCircular])
  }
}

private struct SpikeToggleView: View {
  let entry: SpikeEntry

  var body: some View {
    Button(intent: ToggleActivityIntent()) {
      SpikeRingView(snapshot: entry.snapshot)
    }
    .buttonStyle(.plain)
    .containerBackground(.fill.tertiary, for: .widget)
  }
}

/// Phase 2 spike — open-app via `widgetURL`.
struct SpikeOpenAppComplication: Widget {
  let kind = "SpikeOpenApp"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SpikeTimelineProvider()) { entry in
      SpikeRingView(snapshot: entry.snapshot)
        .widgetURL(URL(string: "activitytracker://open")!)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Open App (Spike)")
    .description("Tap to open Activity Tracker.")
    .supportedFamilies([.accessoryCircular])
  }
}

private struct SpikeRingView: View {
  let snapshot: WidgetSnapshot

  var body: some View {
    ZStack {
      if snapshot.isActive {
        Circle()
          .fill(.primary)
      } else {
        Circle()
          .strokeBorder(.primary, lineWidth: 2)
      }

      Text(countText)
        .font(.system(size: 20, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(snapshot.isActive ? Color.black : Color.primary)
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
    .padding(2)
  }

  private var countText: String {
    snapshot.todayCount > 99 ? "99+" : "\(snapshot.todayCount)"
  }
}

struct SpikeEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot
}

struct SpikeTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> SpikeEntry {
    SpikeEntry(date: .now, snapshot: WidgetSnapshot(isActive: false, todayCount: 0))
  }

  func getSnapshot(in context: Context, completion: @escaping @Sendable (SpikeEntry) -> Void) {
    completion(placeholder(in: context))
  }

  func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SpikeEntry>) -> Void) {
    Task {
      let entry = await loadEntry()
      completion(Timeline(entries: [entry], policy: .never))
    }
  }

  func snapshot(in context: Context) async -> SpikeEntry {
    await loadEntry()
  }

  func timeline(in context: Context) async -> Timeline<SpikeEntry> {
    let entry = await loadEntry()
    return Timeline(entries: [entry], policy: .never)
  }

  private func loadEntry() async -> SpikeEntry {
    IntentDependencies.bootstrap()
    @Dependency(\.activityDatabase) var database
    let snapshot =
      (try? await database.snapshot()) ?? WidgetSnapshot(isActive: false, todayCount: 0)
    return SpikeEntry(date: .now, snapshot: snapshot)
  }
}
