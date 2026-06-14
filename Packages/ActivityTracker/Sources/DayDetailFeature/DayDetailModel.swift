import Database
import Foundation

/// One activity interval clipped to a single calendar day.
public struct DayActivityInterval: Equatable, Sendable, Identifiable {
  public var id: UUID
  public var start: Date
  public var end: Date
  public var isInProgress: Bool

  public init(id: UUID, start: Date, end: Date, isInProgress: Bool) {
    self.id = id
    self.start = start
    self.end = end
    self.isInProgress = isInProgress
  }

  public var duration: TimeInterval {
    max(end.timeIntervalSince(start), 0)
  }
}

/// Builds day-scoped activity intervals from overlapping sessions.
public func makeDayActivityIntervals(
  activities: [Activity],
  calendar: Calendar,
  now: Date,
  dayStart: Date
) -> [DayActivityInterval] {
  guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
    return []
  }

  return activities.compactMap { activity -> DayActivityInterval? in
    let activityEnd = activity.endedAt ?? now
    guard activity.startedAt < dayEnd, activityEnd > dayStart else { return nil }

    let intervalStart = max(activity.startedAt, dayStart)
    let intervalEnd = min(activityEnd, dayEnd)
    let isInProgress = activity.endedAt == nil && now >= dayStart && now < dayEnd

    return DayActivityInterval(
      id: activity.id,
      start: intervalStart,
      end: intervalEnd,
      isInProgress: isInProgress
    )
  }
  .sorted { $0.start < $1.start }
}
