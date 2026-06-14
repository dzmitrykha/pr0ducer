import Dependencies
import DependenciesMacros
import Foundation
import GRDB
import IssueReporting
import Shared
import SQLiteData

public enum ActivityDatabaseError: Error, Equatable, Sendable {
  case invalidID(String)
}

@DependencyClient
public struct ActivityDatabase: Sendable {
  public var currentActivity: @Sendable () async throws -> Activity?
  public var todayCount: @Sendable () async throws -> Int
  public var activities:
    @Sendable (_ dayStart: Date, _ dayEnd: Date) async throws -> [Activity]
  public var snapshot: @Sendable () async throws -> WidgetSnapshot
  public var start: @Sendable (_ now: Date) async throws -> Activity
  public var stop: @Sendable (_ now: Date) async throws -> Void
  public var toggle: @Sendable (_ now: Date) async throws -> WidgetSnapshot
  public var deleteAll: @Sendable () async throws -> Void = { }
}

extension ActivityDatabase {
  /// Builds a live client backed by the given database writer.
  public static func live(database: any DatabaseWriter) -> Self {
    Self(
      currentActivity: {
        try database.read { db in
          guard let record = try ActivityRecord.where { $0.endedAt.is(nil) }.fetchOne(db) else {
            return nil
          }
          return try Activity(record: record)
        }
      },
      todayCount: {
        @Dependency(\.calendar) var calendar
        @Dependency(\.date) var date
        let now = date.now
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
          return 0
        }
        return try countActivities(
          startingIn: dayStart..<dayEnd,
          database: database
        )
      },
      activities: { dayStart, dayEnd in
        let rangeStart = EpochDate.encode(dayStart)
        let rangeEnd = EpochDate.encode(dayEnd)
        return try database.read { db in
          let records = try ActivityRecord
            .where { record in
              record.startedAt < rangeEnd
                && #sql("coalesce(\(record.endedAt), 9999999999) > \(rangeStart)")
            }
            .order(by: \.startedAt)
            .fetchAll(db)
          return try records.map { try Activity(record: $0) }
        }
      },
      snapshot: {
        try makeSnapshot(database: database)
      },
      start: { now in
        try database.write { db in
          if let existing = try ActivityRecord.where { $0.endedAt.is(nil) }.fetchOne(db) {
            return try Activity(record: existing)
          }
          let id = UUID()
          let record = ActivityRecord(
            id: Activity.normalizedID(id),
            startedAt: EpochDate.encode(now),
            endedAt: nil,
            createdAt: EpochDate.encode(now)
          )
          try ActivityRecord.insert { record }.execute(db)
          return Activity(id: id, startedAt: now, endedAt: nil, createdAt: now)
        }
      },
      stop: { now in
        try database.write { db in
          try ActivityRecord
            .where { $0.endedAt.is(nil) }
            .update { $0.endedAt = #bind(EpochDate.encode(now)) }
            .execute(db)
        }
      },
      toggle: { now in
        try database.write { db in
          if let existing = try ActivityRecord.where { $0.endedAt.is(nil) }.fetchOne(db) {
            try ActivityRecord
              .where { $0.id.eq(existing.id) }
              .update { $0.endedAt = #bind(EpochDate.encode(now)) }
              .execute(db)
          } else {
            let id = UUID()
            let record = ActivityRecord(
              id: Activity.normalizedID(id),
              startedAt: EpochDate.encode(now),
              endedAt: nil,
              createdAt: EpochDate.encode(now)
            )
            try ActivityRecord.insert { record }.execute(db)
          }
        }
        return try makeSnapshot(database: database)
      },
      deleteAll: {
        try database.write { db in
          try ActivityRecord.delete().execute(db)
        }
      }
    )
  }

  /// In-memory database with seed data for previews.
  private static func makePreview() throws -> Self {
    let database = try DatabaseBootstrap.inMemory()
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    try database.write { db in
      let completed = ActivityRecord(
        id: Activity.normalizedID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!),
        startedAt: EpochDate.encode(now),
        endedAt: EpochDate.encode(now.addingTimeInterval(3_600)),
        createdAt: EpochDate.encode(now)
      )
      try ActivityRecord.insert { completed }.execute(db)

      let inProgress = ActivityRecord(
        id: Activity.normalizedID(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!),
        startedAt: EpochDate.encode(now.addingTimeInterval(3_700)),
        endedAt: nil,
        createdAt: EpochDate.encode(now.addingTimeInterval(3_700))
      )
      try ActivityRecord.insert { inProgress }.execute(db)
    }
    return Self.live(database: database)
  }
}

extension ActivityDatabase: DependencyKey {
  public static let liveValue: ActivityDatabase = {
    do {
      return live(database: try DatabaseBootstrap.persistent())
    } catch {
      do {
        return live(database: try DatabaseBootstrap.inMemory())
      } catch {
        reportIssue("Failed to bootstrap database: \(error)")
        return Self()
      }
    }
  }()

  public static let previewValue: ActivityDatabase = (try? makePreview()) ?? Self()

  public static let testValue = Self()
}

extension DependencyValues {
  public var activityDatabase: ActivityDatabase {
    get { self[ActivityDatabase.self] }
    set { self[ActivityDatabase.self] = newValue }
  }
}

// MARK: - Query helpers

private func makeSnapshot(database: any DatabaseWriter) throws -> WidgetSnapshot {
  @Dependency(\.calendar) var calendar
  @Dependency(\.date) var date
  let now = date.now
  return try database.read { db in
    let isActive = try ActivityRecord.where { $0.endedAt.is(nil) }.fetchOne(db) != nil
    let dayStart = calendar.startOfDay(for: now)
    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now
    let todayCount = try countActivities(
      startingIn: dayStart..<dayEnd,
      database: database,
      db: db
    )
    return WidgetSnapshot(isActive: isActive, todayCount: todayCount)
  }
}

private func countActivities(
  startingIn range: Range<Date>,
  database: any DatabaseWriter,
  db: Database? = nil
) throws -> Int {
  let rangeStart = EpochDate.encode(range.lowerBound)
  let rangeEnd = EpochDate.encode(range.upperBound)
  if let db {
    return try ActivityRecord
      .where { $0.startedAt >= rangeStart && $0.startedAt < rangeEnd }
      .fetchCount(db)
  }
  return try database.read { db in
    try ActivityRecord
      .where { $0.startedAt >= rangeStart && $0.startedAt < rangeEnd }
      .fetchCount(db)
  }
}
