import ActivityIntents
import Dependencies
import Shared
import WidgetKit

struct ActivitySnapshotEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot
}

struct ActivitySnapshotProvider: TimelineProvider {
  func placeholder(in context: Context) -> ActivitySnapshotEntry {
    ActivitySnapshotEntry(
      date: .now,
      snapshot: WidgetSnapshot(isActive: false, todayCount: 3)
    )
  }

  func getSnapshot(in context: Context, completion: @escaping @Sendable (ActivitySnapshotEntry) -> Void) {
    if context.isPreview {
      completion(placeholder(in: context))
      return
    }
    Task {
      completion(await loadEntry())
    }
  }

  func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ActivitySnapshotEntry>) -> Void) {
    Task {
      completion(await makeTimeline())
    }
  }

  func snapshot(in context: Context) async -> ActivitySnapshotEntry {
    if context.isPreview {
      return placeholder(in: context)
    }
    return await loadEntry()
  }

  func timeline(in context: Context) async -> Timeline<ActivitySnapshotEntry> {
    await makeTimeline()
  }

  private func loadEntry() async -> ActivitySnapshotEntry {
    IntentDependencies.bootstrap()
    @Dependency(\.activityDatabase) var database
    @Dependency(\.date) var date
    let snapshot =
      (try? await database.snapshot()) ?? WidgetSnapshot(isActive: false, todayCount: 0)
    return ActivitySnapshotEntry(date: date.now, snapshot: snapshot)
  }

  private func makeTimeline() async -> Timeline<ActivitySnapshotEntry> {
    let entry = await loadEntry()
    let reloadDate = fallbackReloadDate(for: entry.snapshot, at: entry.date)
    return Timeline(entries: [entry], policy: .after(reloadDate))
  }

  /// Periodic fallback when `reloadAllTimelines()` is not triggered (e.g. midnight count rollover).
  private func fallbackReloadDate(for snapshot: WidgetSnapshot, at date: Date) -> Date {
    @Dependency(\.calendar) var calendar
    let startOfToday = calendar.startOfDay(for: date)
    let startOfTomorrow =
      calendar.date(byAdding: .day, value: 1, to: startOfToday)
      ?? date.addingTimeInterval(86_400)

    if snapshot.isActive {
      let hourly =
        calendar.date(byAdding: .hour, value: 1, to: date)
        ?? date.addingTimeInterval(3_600)
      return min(hourly, startOfTomorrow)
    }
    return startOfTomorrow
  }
}
