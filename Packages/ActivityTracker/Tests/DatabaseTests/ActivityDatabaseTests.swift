import Database
import Dependencies
import DependenciesTestSupport
import Foundation
import GRDB
import Shared
import SQLiteData
import Testing

@Suite(.serialized)
struct ActivityDatabaseTests {
  @Test func migrationCreatesSchemaAndEnablesForeignKeys() throws {
    let database = try DatabaseBootstrap.inMemory()
    try assertForeignKeysEnabled(database)

    try database.read { db in
      let tableExists = try Bool.fetchOne(
        db,
        sql: """
          SELECT COUNT(*) > 0 FROM sqlite_master
          WHERE type = 'table' AND name = 'activities'
          """
      )
      #expect(tableExists == true)

      let startedAtIndex = try Bool.fetchOne(
        db,
        sql: """
          SELECT COUNT(*) > 0 FROM sqlite_master
          WHERE type = 'index' AND name = 'activities_startedAt_idx'
          """
      )
      #expect(startedAtIndex == true)

      let inProgressIndex = try Bool.fetchOne(
        db,
        sql: """
          SELECT COUNT(*) > 0 FROM sqlite_master
          WHERE type = 'index' AND name = 'activities_in_progress_idx'
          """
      )
      #expect(inProgressIndex == true)
    }

    let persistentURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(UUID().uuidString).sqlite")
    let persistent = try DatabaseBootstrap.persistent(url: persistentURL)
    try assertForeignKeysEnabled(persistent)
    try FileManager.default.removeItem(at: persistentURL)
  }

  @Test func startAndCurrentActivity() async throws {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    try await withClient(now: fixedDate) { database, client in
      let started = try await client.start(fixedDate)
      #expect(started.isInProgress)
      #expect(started.startedAt == fixedDate)

      let current = try await client.currentActivity()
      #expect(current?.id == started.id)
      #expect(current?.isInProgress == true)

      let secondStart = try await client.start(fixedDate.addingTimeInterval(60))
      #expect(secondStart.id == started.id)

      let inProgressCount = try await database.read { db in
        try Int.fetchOne(
          db,
          sql: "SELECT COUNT(*) FROM activities WHERE endedAt IS NULL"
        )
      }
      #expect(inProgressCount == 1)
    }
  }

  @Test func stopEndsActivityAndIsNoOpWhenIdle() async throws {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    try await withClient(now: fixedDate) { _, client in
      try await client.stop(fixedDate)
      #expect(try await client.currentActivity() == nil)

      _ = try await client.start(fixedDate)
      try await client.stop(fixedDate.addingTimeInterval(1_800))

      let current = try await client.currentActivity()
      #expect(current == nil)

      let completed = try await client.activities(
        dayStart: dayStart(for: fixedDate),
        dayEnd: dayEnd(for: fixedDate)
      )
      #expect(completed.count == 1)
      #expect(completed[0].endedAt == fixedDate.addingTimeInterval(1_800))

      try await client.stop(fixedDate.addingTimeInterval(9_999))
      #expect(try await client.currentActivity() == nil)
    }
  }

  @Test func toggleStartsStopsAndReturnsSnapshot() async throws {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    try await withClient(now: fixedDate) { _, client in
      let idleSnapshot = try await client.toggle(fixedDate)
      #expect(idleSnapshot == WidgetSnapshot(isActive: true, todayCount: 1))

      let activeSnapshot = try await client.toggle(fixedDate.addingTimeInterval(300))
      #expect(activeSnapshot == WidgetSnapshot(isActive: false, todayCount: 1))
      #expect(try await client.currentActivity() == nil)
    }
  }

  @Test func todayCountRespectsCalendarDayAndTimeZone() async throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: -14_400)! // UTC-4

    let day = makeDate(year: 2026, month: 6, day: 14, hour: 12, calendar: calendar)
    let previousDay = calendar.date(byAdding: .day, value: -1, to: day)!
    let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!

    let database = try DatabaseBootstrap.inMemory()
    try await database.write { db in
      let yesterday = ActivityRecord(
        id: Activity.normalizedID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!),
        startedAt: EpochDate.encode(previousDay),
        endedAt: EpochDate.encode(previousDay.addingTimeInterval(600)),
        createdAt: EpochDate.encode(previousDay)
      )
      let todayMorning = ActivityRecord(
        id: Activity.normalizedID(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!),
        startedAt: EpochDate.encode(day),
        endedAt: EpochDate.encode(day.addingTimeInterval(600)),
        createdAt: EpochDate.encode(day)
      )
      let todayAfternoon = ActivityRecord(
        id: Activity.normalizedID(UUID(uuidString: "00000000-0000-0000-0000-000000000003")!),
        startedAt: EpochDate.encode(day.addingTimeInterval(3_600)),
        endedAt: nil,
        createdAt: EpochDate.encode(day.addingTimeInterval(3_600))
      )
      let tomorrow = ActivityRecord(
        id: Activity.normalizedID(UUID(uuidString: "00000000-0000-0000-0000-000000000004")!),
        startedAt: EpochDate.encode(nextDay),
        endedAt: nil,
        createdAt: EpochDate.encode(nextDay)
      )
      try ActivityRecord.insert { yesterday }.execute(db)
      try ActivityRecord.insert { todayMorning }.execute(db)
      try ActivityRecord.insert { todayAfternoon }.execute(db)
      try ActivityRecord.insert { tomorrow }.execute(db)
    }

    let client = ActivityDatabase.live(database: database)
    let count = try await withDependencies {
      $0.calendar = calendar
      $0.timeZone = calendar.timeZone
      $0.date.now = day.addingTimeInterval(7_200)
    } operation: {
      try await client.todayCount()
    }
    #expect(count == 2)
  }

  @Test func activitiesReturnsOverlappingRowsIncludingInProgress() async throws {
    let calendar = makeCalendar()
    let dayStart = makeDate(year: 2026, month: 6, day: 14, hour: 0, calendar: calendar)
    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

    let withinDay = makeDate(year: 2026, month: 6, day: 14, hour: 9, calendar: calendar)
    let spanningStart = makeDate(year: 2026, month: 6, day: 13, hour: 23, calendar: calendar)
    let afterDay = makeDate(year: 2026, month: 6, day: 15, hour: 1, calendar: calendar)

    let database = try DatabaseBootstrap.inMemory()
    try await database.write { db in
      let completed = ActivityRecord(
        id: Activity.normalizedID(UUID(uuidString: "00000000-0000-0000-0000-000000000010")!),
        startedAt: EpochDate.encode(withinDay),
        endedAt: EpochDate.encode(withinDay.addingTimeInterval(1_800)),
        createdAt: EpochDate.encode(withinDay)
      )
      let inProgress = ActivityRecord(
        id: Activity.normalizedID(UUID(uuidString: "00000000-0000-0000-0000-000000000011")!),
        startedAt: EpochDate.encode(withinDay.addingTimeInterval(7_200)),
        endedAt: nil,
        createdAt: EpochDate.encode(withinDay.addingTimeInterval(7_200))
      )
      let midnightSpan = ActivityRecord(
        id: Activity.normalizedID(UUID(uuidString: "00000000-0000-0000-0000-000000000012")!),
        startedAt: EpochDate.encode(spanningStart),
        endedAt: EpochDate.encode(dayStart.addingTimeInterval(1_800)),
        createdAt: EpochDate.encode(spanningStart)
      )
      let future = ActivityRecord(
        id: Activity.normalizedID(UUID(uuidString: "00000000-0000-0000-0000-000000000013")!),
        startedAt: EpochDate.encode(afterDay),
        endedAt: nil,
        createdAt: EpochDate.encode(afterDay)
      )
      try ActivityRecord.insert { completed }.execute(db)
      try ActivityRecord.insert { inProgress }.execute(db)
      try ActivityRecord.insert { midnightSpan }.execute(db)
      try ActivityRecord.insert { future }.execute(db)
    }

    let client = ActivityDatabase.live(database: database)
    let activities = try await client.activities(dayStart: dayStart, dayEnd: dayEnd)
    #expect(activities.count == 3)
    #expect(activities.contains(where: { $0.id.uuidString.lowercased() == "00000000-0000-0000-0000-000000000010" }))
    #expect(activities.contains(where: { $0.isInProgress }))
    #expect(activities.contains(where: { $0.id.uuidString.lowercased() == "00000000-0000-0000-0000-000000000012" }))
    #expect(!activities.contains(where: { $0.id.uuidString.lowercased() == "00000000-0000-0000-0000-000000000013" }))
  }

  @Test func deleteRemovesSingleActivity() async throws {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    let activityID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    try await withClient(now: fixedDate) { database, client in
      try await database.write { db in
        let record = ActivityRecord(
          id: Activity.normalizedID(activityID),
          startedAt: EpochDate.encode(fixedDate),
          endedAt: EpochDate.encode(fixedDate.addingTimeInterval(600)),
          createdAt: EpochDate.encode(fixedDate)
        )
        try ActivityRecord.insert { record }.execute(db)
      }

      try await client.delete(activityID)

      let count = try await database.read { db in
        try ActivityRecord.fetchCount(db)
      }
      #expect(count == 0)
    }
  }

  @Test func snapshotReflectsActiveStateAndTodayCount() async throws {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    try await withClient(now: fixedDate) { _, client in
      #expect(try await client.snapshot() == WidgetSnapshot(isActive: false, todayCount: 0))

      _ = try await client.start(fixedDate)
      #expect(try await client.snapshot() == WidgetSnapshot(isActive: true, todayCount: 1))
    }
  }
}

// MARK: - Helpers

private func withClient<T>(
  now: Date,
  calendar: Calendar = makeCalendar(),
  _ operation: (any DatabaseWriter, ActivityDatabase) async throws -> T
) async throws -> T {
  let database = try DatabaseBootstrap.inMemory()
  let client = ActivityDatabase.live(database: database)
  return try await withDependencies {
    $0.calendar = calendar
    $0.timeZone = calendar.timeZone
    $0.date.now = now
  } operation: {
    try await operation(database, client)
  }
}

private func assertForeignKeysEnabled(_ database: any DatabaseWriter) throws {
  try database.read { db in
    let foreignKeys = try Bool.fetchOne(db, sql: "PRAGMA foreign_keys")
    #expect(foreignKeys == true)
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

private func dayStart(for date: Date, calendar: Calendar = makeCalendar()) -> Date {
  calendar.startOfDay(for: date)
}

private func dayEnd(for date: Date, calendar: Calendar = makeCalendar()) -> Date {
  calendar.date(byAdding: .day, value: 1, to: dayStart(for: date, calendar: calendar))!
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
