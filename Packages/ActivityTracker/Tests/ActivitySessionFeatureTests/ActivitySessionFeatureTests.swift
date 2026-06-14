import ActivitySessionFeature
import ComposableArchitecture
import Database
import Dependencies
import DependenciesTestSupport
import Foundation
import Shared
import Testing

@Suite(.serialized)
@MainActor
struct ActivitySessionFeatureTests {
  @Test func countdownCompletesAndStartsActivity() async throws {
    let calendar = makeCalendar()
    let now = makeDate(year: 2026, month: 6, day: 14, hour: 10, calendar: calendar)
    let database = try DatabaseBootstrap.inMemory()
    let client = ActivityDatabase.live(database: database)
    let clock = TestClock()

    let store = TestStore(
      initialState: ActivitySessionFeature.State(pendingAction: .start)
    ) {
      ActivitySessionFeature()
    } withDependencies: {
      $0.activityDatabase = client
      $0.calendar = calendar
      $0.timeZone = calendar.timeZone
      $0.date.now = now
      $0.continuousClock = clock
    }
    store.exhaustivity = .off

    await store.send(.onAppear)
    await clock.advance(by: .seconds(ActivitySessionFeature.State.countdownDuration))
    await store.skipReceivedActions()

    let current = try await client.currentActivity()
    #expect(current?.startedAt == now)
  }

  @Test func countdownCompletesAndStopsActivity() async throws {
    let calendar = makeCalendar()
    let now = makeDate(year: 2026, month: 6, day: 14, hour: 10, calendar: calendar)
    let database = try DatabaseBootstrap.inMemory()
    let client = ActivityDatabase.live(database: database)
    let clock = TestClock()
    _ = try await client.start(now)

    let store = TestStore(
      initialState: ActivitySessionFeature.State(pendingAction: .stop)
    ) {
      ActivitySessionFeature()
    } withDependencies: {
      $0.activityDatabase = client
      $0.calendar = calendar
      $0.timeZone = calendar.timeZone
      $0.date.now = now.addingTimeInterval(3_600)
      $0.continuousClock = clock
    }
    store.exhaustivity = .off

    await store.send(.onAppear)
    await clock.advance(by: .seconds(ActivitySessionFeature.State.countdownDuration))
    await store.skipReceivedActions()

    let current = try await client.currentActivity()
    #expect(current == nil)
  }

  @Test func cancelMakesNoDatabaseChange() async throws {
    let calendar = makeCalendar()
    let now = makeDate(year: 2026, month: 6, day: 14, hour: 10, calendar: calendar)
    let database = try DatabaseBootstrap.inMemory()
    let client = ActivityDatabase.live(database: database)
    let clock = TestClock()

    let store = TestStore(
      initialState: ActivitySessionFeature.State(pendingAction: .start)
    ) {
      ActivitySessionFeature()
    } withDependencies: {
      $0.activityDatabase = client
      $0.calendar = calendar
      $0.timeZone = calendar.timeZone
      $0.date.now = now
      $0.continuousClock = clock
    }

    await store.send(.onAppear)
    await store.send(.cancelTapped)
    await store.receive(.delegate(.cancelled))

    let current = try await client.currentActivity()
    #expect(current == nil)
  }
}

// MARK: - Helpers

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
