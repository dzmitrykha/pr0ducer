import ComposableArchitecture
import Database
import DayListFeature
import Dependencies
import DependenciesTestSupport
import Foundation
import Shared
import Testing

@Suite(.serialized)
@MainActor
struct DayListFeatureTests {
  @Test func refreshPopulatesDayCards() async throws {
    let calendar = makeCalendar()
    let now = makeDate(year: 2026, month: 6, day: 14, hour: 12, calendar: calendar)
    let database = try DatabaseBootstrap.inMemory()
    let client = ActivityDatabase.live(database: database)
    try await seedActivity(
      database: client,
      startedAt: makeDate(year: 2026, month: 6, day: 14, hour: 9, calendar: calendar),
      endedAt: makeDate(year: 2026, month: 6, day: 14, hour: 10, calendar: calendar)
    )

    let store = TestStore(initialState: DayListFeature.State()) {
      DayListFeature()
    } withDependencies: {
      $0.activityDatabase = client
      $0.calendar = calendar
      $0.timeZone = calendar.timeZone
      $0.date.now = now
    }
    store.exhaustivity = .off

    await store.send(.refresh) {
      $0.isLoading = true
    }
    await store.skipReceivedActions()

    #expect(store.state.cards.count == DayCardModel.defaultDayWindow)
    #expect(store.state.cards.first?.count == 1)
    #expect(store.state.cards.first?.segments.count == 1)
    let firstSegment = store.state.cards.first?.segments.first
    #expect(firstSegment?.start.isApproximatelyEqual(to: 9.0 / 24.0) == true)
    #expect(firstSegment?.end.isApproximatelyEqual(to: 10.0 / 24.0) == true)
    #expect(store.state.referenceDate == now)
  }

  @Test func refreshReloadsAfterDatabaseChange() async throws {
    let calendar = makeCalendar()
    let now = makeDate(year: 2026, month: 6, day: 14, hour: 12, calendar: calendar)
    let database = try DatabaseBootstrap.inMemory()
    let client = ActivityDatabase.live(database: database)

    let store = TestStore(initialState: DayListFeature.State()) {
      DayListFeature()
    } withDependencies: {
      $0.activityDatabase = client
      $0.calendar = calendar
      $0.timeZone = calendar.timeZone
      $0.date.now = now
    }
    store.exhaustivity = .off

    await store.send(.refresh) {
      $0.isLoading = true
    }
    await store.skipReceivedActions()
    #expect(store.state.cards.first?.count == 0)

    try await seedActivity(
      database: client,
      startedAt: makeDate(year: 2026, month: 6, day: 14, hour: 8, calendar: calendar),
      endedAt: makeDate(year: 2026, month: 6, day: 14, hour: 9, calendar: calendar)
    )

    await store.send(.refresh) {
      $0.isLoading = true
    }
    await store.skipReceivedActions()

    #expect(store.state.cards.first?.count == 1)
    #expect(store.state.cards.first?.segments.count == 1)
  }

  @Test func emptyDayShowsZeroCountAndEmptyTrack() async throws {
    let calendar = makeCalendar()
    let now = makeDate(year: 2026, month: 6, day: 14, hour: 12, calendar: calendar)
    let database = try DatabaseBootstrap.inMemory()
    let client = ActivityDatabase.live(database: database)

    let store = TestStore(initialState: DayListFeature.State(dayWindow: 1)) {
      DayListFeature()
    } withDependencies: {
      $0.activityDatabase = client
      $0.calendar = calendar
      $0.timeZone = calendar.timeZone
      $0.date.now = now
    }
    store.exhaustivity = .off

    await store.send(.refresh) {
      $0.isLoading = true
    }
    await store.skipReceivedActions()

    #expect(store.state.cards.count == 1)
    #expect(store.state.cards[0].count == 0)
    #expect(store.state.cards[0].segments.isEmpty)
  }
}

// MARK: - Helpers

private extension Double {
  func isApproximatelyEqual(to other: Double, tolerance: Double = 0.0001) -> Bool {
    Swift.abs(self - other) <= tolerance
  }
}

private func seedActivity(
  database: ActivityDatabase,
  startedAt: Date,
  endedAt: Date?
) async throws {
  _ = try await database.start(startedAt)
  if let endedAt {
    try await database.stop(endedAt)
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
