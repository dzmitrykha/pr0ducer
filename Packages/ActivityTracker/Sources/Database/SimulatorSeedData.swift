#if targetEnvironment(simulator)
import Dependencies
import Foundation
import Shared

/// Seeds representative activity history when running in the Simulator.
public enum SimulatorSeedData {
  public static let dayCount = 30
  /// Bump to force a wipe + reseed after changing the seed dataset.
  public static let seedVersion = 2
  private static let seedVersionKey = "simulatorSeedVersion"

  /// Wipes and inserts sample sessions for the last 30 days when the seed version changes.
  public static func seedIfNeeded() async throws {
    @Dependency(\.activityDatabase) var database
    @Dependency(\.calendar) var calendar
    @Dependency(\.date) var date

    let defaults = UserDefaults(suiteName: AppGroup.identifier)
    let appliedVersion = defaults?.integer(forKey: seedVersionKey) ?? 0
    guard appliedVersion != seedVersion else { return }

    try await database.deleteAll()

    let now = date.now
    let todayStart = calendar.startOfDay(for: now)

    for dayOffset in stride(from: dayCount - 1, through: 0, by: -1) {
      guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) else {
        continue
      }
      let sessionCount = sessionsPerDay(dayOffset: dayOffset)
      for sessionIndex in 0..<sessionCount {
        let startedAt = sessionStart(
          dayStart: dayStart,
          sessionIndex: sessionIndex,
          sessionCount: sessionCount,
          calendar: calendar
        )
        let isTodayInProgress = dayOffset == 0 && sessionIndex == sessionCount - 1

        _ = try await database.start(startedAt)
        if !isTodayInProgress {
          let duration = sessionDuration(
            dayOffset: dayOffset,
            sessionIndex: sessionIndex,
            sessionCount: sessionCount
          )
          try await database.stop(startedAt.addingTimeInterval(duration))
        }
      }
    }

    defaults?.set(seedVersion, forKey: seedVersionKey)
  }

  private static func sessionsPerDay(dayOffset: Int) -> Int {
    switch dayOffset {
    case 0: 12
    case 1: 15
    case 2: 11
    case 5: 14
    case 7: 10
    case 10: 13
    case 14: 11
    case 21: 12
    default:
      switch dayOffset % 5 {
      case 0: 1
      case 1: 3
      case 2: 5
      case 3: 2
      default: 4
      }
    }
  }

  private static func sessionDuration(
    dayOffset: Int,
    sessionIndex: Int,
    sessionCount: Int
  ) -> TimeInterval {
    if sessionCount > 10 {
      return TimeInterval((18 + (sessionIndex % 4) * 4) * 60)
    }
    return TimeInterval(30 * 60 + (dayOffset + sessionIndex) * 5 * 60)
  }

  private static func sessionStart(
    dayStart: Date,
    sessionIndex: Int,
    sessionCount: Int,
    calendar: Calendar
  ) -> Date {
    let startMinute = 6 * 60
    let endMinute = 23 * 60
    let available = endMinute - startMinute
    let spacing = sessionCount > 1 ? available / sessionCount : 0
    let jitter = (sessionIndex * 11) % 12
    let minuteOfDay = min(
      startMinute + sessionIndex * spacing + jitter,
      endMinute - 15
    )
    let hour = minuteOfDay / 60
    let minute = minuteOfDay % 60
    return calendar.date(
      bySettingHour: hour,
      minute: minute,
      second: 0,
      of: dayStart
    ) ?? dayStart.addingTimeInterval(TimeInterval(sessionIndex) * 3_600)
  }
}
#endif
