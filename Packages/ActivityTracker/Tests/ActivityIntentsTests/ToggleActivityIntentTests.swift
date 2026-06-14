import ActivityIntents
import Database
import Dependencies
import DependenciesTestSupport
import Foundation
import Shared
import Testing

@Suite(.serialized)
struct ToggleActivityIntentTests {
  @Test func toggleStartsThenStopsActivity() async throws {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    try await withIntentDependencies(now: fixedDate) { client in
      #expect(try await client.snapshot() == WidgetSnapshot(isActive: false, todayCount: 0))

      _ = try await ToggleActivityIntent().perform()
      #expect(try await client.snapshot() == WidgetSnapshot(isActive: true, todayCount: 1))

      _ = try await ToggleActivityIntent().perform()
      #expect(try await client.snapshot() == WidgetSnapshot(isActive: false, todayCount: 1))
    }
  }

  @Test func startIsIdempotentWhenAlreadyRunning() async throws {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    try await withIntentDependencies(now: fixedDate) { client in
      _ = try await StartActivityIntent().perform()
      let first = try await client.currentActivity()

      _ = try await StartActivityIntent().perform()
      let second = try await client.currentActivity()

      #expect(first?.id == second?.id)
      #expect(try await client.snapshot().todayCount == 1)
    }
  }

  @Test func stopIsNoOpWhenIdle() async throws {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    try await withIntentDependencies(now: fixedDate) { client in
      _ = try await StopActivityIntent().perform()
      #expect(try await client.currentActivity() == nil)
      #expect(try await client.snapshot() == WidgetSnapshot(isActive: false, todayCount: 0))
    }
  }

  @Test func startThenStop() async throws {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    try await withIntentDependencies(now: fixedDate) { client in
      _ = try await StartActivityIntent().perform()
      #expect(try await client.snapshot().isActive)

      _ = try await StopActivityIntent().perform()
      #expect(try await client.snapshot() == WidgetSnapshot(isActive: false, todayCount: 1))
    }
  }
}

// MARK: - Helpers

private func withIntentDependencies<T>(
  now: Date,
  calendar: Calendar = makeCalendar(),
  _ operation: (ActivityDatabase) async throws -> T
) async throws -> T {
  let database = try DatabaseBootstrap.inMemory()
  let client = ActivityDatabase.live(database: database)
  return try await withDependencies {
    $0.activityDatabase = client
    $0.calendar = calendar
    $0.timeZone = calendar.timeZone
    $0.date.now = now
  } operation: {
    try await operation(client)
  }
}

private func makeCalendar() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0)!
  return calendar
}

private func makeDate(
  year: Int,
  month: Int,
  day: Int,
  hour: Int,
  calendar: Calendar? = nil
) -> Date {
  let calendar = calendar ?? makeCalendar()
  return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}
