import Database
import Foundation

/// A clipped activity interval on a single calendar day, expressed as fractions of the day.
public struct ActivitySegment: Equatable, Sendable, Identifiable {
  public var id: UUID
  public var start: Double
  public var end: Double
  public var isInProgress: Bool

  public init(id: UUID, start: Double, end: Double, isInProgress: Bool) {
    self.id = id
    self.start = start
    self.end = end
    self.isInProgress = isInProgress
  }
}

/// Presentation model for one day row in the list.
public struct DayCard: Equatable, Sendable, Identifiable {
  public var date: Date
  public var count: Int
  public var segments: [ActivitySegment]

  public var id: Date { date }

  public var isEmpty: Bool {
    // swiftlint:disable:next empty_count
    count == 0 && segments.isEmpty
  }

  public init(date: Date, count: Int, segments: [ActivitySegment]) {
    self.date = date
    self.count = count
    self.segments = segments
  }
}

public enum DayCardModel {
  public static let defaultDayWindow = 30
  public static let olderDaysBatchSize = 14
}

/// Builds descending day cards (today first) from overlapping activities.
public func makeDayCards(
  activities: [Activity],
  calendar: Calendar,
  now: Date,
  dayCount: Int = DayCardModel.defaultDayWindow
) -> [DayCard] {
  guard dayCount > 0 else { return [] }

  let todayStart = calendar.startOfDay(for: now)
  var days: [Date] = []
  var day = todayStart
  for _ in 0..<dayCount {
    days.append(day)
    guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
    day = previous
  }

  return days.map { dayStart in
    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
      return DayCard(date: dayStart, count: 0, segments: [])
    }

    let dayDuration = dayEnd.timeIntervalSince(dayStart)
    let count = activities.filter { $0.startedAt >= dayStart && $0.startedAt < dayEnd }.count

    let segments = activities.compactMap { activity -> ActivitySegment? in
      let activityEnd = activity.endedAt ?? now
      guard activity.startedAt < dayEnd, activityEnd > dayStart else { return nil }

      let segmentStart = max(activity.startedAt, dayStart)
      let segmentEnd = min(activityEnd, dayEnd)
      let isInProgress = activity.endedAt == nil && now >= dayStart && now < dayEnd

      return ActivitySegment(
        id: activity.id,
        start: fractionOfDay(segmentStart, dayStart: dayStart, dayDuration: dayDuration),
        end: fractionOfDay(segmentEnd, dayStart: dayStart, dayDuration: dayDuration),
        isInProgress: isInProgress
      )
    }
    .sorted { $0.start < $1.start }

    return DayCard(date: dayStart, count: count, segments: segments)
  }
}

private func fractionOfDay(
  _ date: Date,
  dayStart: Date,
  dayDuration: TimeInterval
) -> Double {
  guard dayDuration > 0 else { return 0 }
  let offset = date.timeIntervalSince(dayStart)
  return min(max(offset / dayDuration, 0), 1)
}
