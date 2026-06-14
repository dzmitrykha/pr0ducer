import ComposableArchitecture
import CustomDump
import Database
import DayDetailFeature
import Dependencies
import DependenciesTestSupport
import Foundation
import GRDB
import Shared
import SQLiteData
import Testing

@Suite(.serialized)
@MainActor
struct DayDetailFeatureTests {
  @Test func onAppearLoadsIntervalsForDay() async throws {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 15)
    let dayStart = makeDate(year: 2026, month: 6, day: 14, hour: 0)
    let database = try! DatabaseBootstrap.inMemory()
    let client = ActivityDatabase.live(database: database)

    try await database.write { db in
      let morning = ActivityRecord(
        id: Activity.normalizedID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!),
        startedAt: EpochDate.encode(makeDate(year: 2026, month: 6, day: 14, hour: 9)),
        endedAt: EpochDate.encode(makeDate(year: 2026, month: 6, day: 14, hour: 10)),
        createdAt: EpochDate.encode(makeDate(year: 2026, month: 6, day: 14, hour: 9))
      )
      let afternoon = ActivityRecord(
        id: Activity.normalizedID(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!),
        startedAt: EpochDate.encode(makeDate(year: 2026, month: 6, day: 14, hour: 14)),
        endedAt: EpochDate.encode(makeDate(year: 2026, month: 6, day: 14, hour: 15)),
        createdAt: EpochDate.encode(makeDate(year: 2026, month: 6, day: 14, hour: 14))
      )
      try ActivityRecord.insert { morning }.execute(db)
      try ActivityRecord.insert { afternoon }.execute(db)
    }

    let store = TestStore(
      initialState: DayDetailFeature.State(dayStart: dayStart, referenceDate: fixedDate)
    ) {
      DayDetailFeature()
    } withDependencies: {
      $0.activityDatabase = client
      $0.calendar = makeCalendar()
      $0.timeZone = makeCalendar().timeZone
      $0.date.now = fixedDate
    }

    await store.send(.onAppear) {
      $0.isLoading = true
    }
    await store.receive(\.intervalsLoaded) {
      $0.isLoading = false
      $0.referenceDate = fixedDate
      $0.intervals = [
        DayActivityInterval(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          start: makeDate(year: 2026, month: 6, day: 14, hour: 9),
          end: makeDate(year: 2026, month: 6, day: 14, hour: 10),
          isInProgress: false
        ),
        DayActivityInterval(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          start: makeDate(year: 2026, month: 6, day: 14, hour: 14),
          end: makeDate(year: 2026, month: 6, day: 14, hour: 15),
          isInProgress: false
        ),
      ]
    }
  }

  @Test func deleteRemovesActivityAndRefreshes() async throws {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 15)
    let dayStart = makeDate(year: 2026, month: 6, day: 14, hour: 0)
    let activityID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let database = try! DatabaseBootstrap.inMemory()
    let client = ActivityDatabase.live(database: database)

    try await database.write { db in
      let morning = ActivityRecord(
        id: Activity.normalizedID(activityID),
        startedAt: EpochDate.encode(makeDate(year: 2026, month: 6, day: 14, hour: 9)),
        endedAt: EpochDate.encode(makeDate(year: 2026, month: 6, day: 14, hour: 10)),
        createdAt: EpochDate.encode(makeDate(year: 2026, month: 6, day: 14, hour: 9))
      )
      let afternoon = ActivityRecord(
        id: Activity.normalizedID(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!),
        startedAt: EpochDate.encode(makeDate(year: 2026, month: 6, day: 14, hour: 14)),
        endedAt: EpochDate.encode(makeDate(year: 2026, month: 6, day: 14, hour: 15)),
        createdAt: EpochDate.encode(makeDate(year: 2026, month: 6, day: 14, hour: 14))
      )
      try ActivityRecord.insert { morning }.execute(db)
      try ActivityRecord.insert { afternoon }.execute(db)
    }

    var initialState = DayDetailFeature.State(
      dayStart: dayStart,
      referenceDate: fixedDate
    )
    initialState.intervals = [
      DayActivityInterval(
        id: activityID,
        start: makeDate(year: 2026, month: 6, day: 14, hour: 9),
        end: makeDate(year: 2026, month: 6, day: 14, hour: 10),
        isInProgress: false
      ),
      DayActivityInterval(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        start: makeDate(year: 2026, month: 6, day: 14, hour: 14),
        end: makeDate(year: 2026, month: 6, day: 14, hour: 15),
        isInProgress: false
      ),
    ]

    let store = TestStore(initialState: initialState) {
      DayDetailFeature()
    } withDependencies: {
      $0.activityDatabase = client
      $0.calendar = makeCalendar()
      $0.timeZone = makeCalendar().timeZone
      $0.date.now = fixedDate
    }
    store.exhaustivity = .off

    await store.send(.delete(activityID))
    await store.receive(.delegate(.dataChanged))
    await store.receive(\.refresh) {
      $0.isLoading = true
    }
    await store.receive(\.intervalsLoaded) {
      $0.isLoading = false
      $0.intervals = [
        DayActivityInterval(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          start: makeDate(year: 2026, month: 6, day: 14, hour: 14),
          end: makeDate(year: 2026, month: 6, day: 14, hour: 15),
          isInProgress: false
        ),
      ]
    }

    let remaining = try await client.activities(dayStart: dayStart, dayEnd: dayEnd(for: dayStart))
    #expect(remaining.count == 1)
    #expect(remaining[0].id.uuidString.lowercased() == "00000000-0000-0000-0000-000000000002")
  }
}

@Suite
struct DayDetailModelTests {
  @Test func makeDayActivityIntervalsClipsToDay() {
    let calendar = makeCalendar()
    let dayStart = makeDate(year: 2026, month: 6, day: 14, hour: 0, calendar: calendar)
    let now = makeDate(year: 2026, month: 6, day: 14, hour: 16, calendar: calendar)
    let activities = [
      Activity(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        startedAt: makeDate(year: 2026, month: 6, day: 13, hour: 23, calendar: calendar),
        endedAt: makeDate(year: 2026, month: 6, day: 14, hour: 1, calendar: calendar),
        createdAt: makeDate(year: 2026, month: 6, day: 13, hour: 23, calendar: calendar)
      ),
      Activity(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
        startedAt: makeDate(year: 2026, month: 6, day: 14, hour: 9, calendar: calendar),
        endedAt: nil,
        createdAt: makeDate(year: 2026, month: 6, day: 14, hour: 9, calendar: calendar)
      ),
    ]

    let intervals = makeDayActivityIntervals(
      activities: activities,
      calendar: calendar,
      now: now,
      dayStart: dayStart
    )

    #expect(intervals.count == 2)
    #expect(intervals[0].start == dayStart)
    #expect(intervals[0].end == makeDate(year: 2026, month: 6, day: 14, hour: 1, calendar: calendar))
    #expect(intervals[1].isInProgress)
    #expect(intervals[1].end == now)
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

private func dayEnd(for dayStart: Date, calendar: Calendar = makeCalendar()) -> Date {
  calendar.date(byAdding: .day, value: 1, to: dayStart)!
}

@Table("activities")
private struct ActivityRecord: Identifiable, Equatable, Sendable {
  @Column(primaryKey: true)
  var id: String
  var startedAt: Int
  var endedAt: Int?
  var createdAt: Int
}

private enum EpochDate {
  static func encode(_ date: Date) -> Int {
    Int(date.timeIntervalSince1970)
  }
}
