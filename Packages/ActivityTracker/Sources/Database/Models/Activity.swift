import Foundation
import SQLiteData

/// Domain model for a tracked activity session.
public struct Activity: Identifiable, Equatable, Sendable {
  public let id: UUID
  public var startedAt: Date
  public var endedAt: Date?
  public var createdAt: Date

  public init(id: UUID, startedAt: Date, endedAt: Date?, createdAt: Date) {
    self.id = id
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.createdAt = createdAt
  }

  public var isInProgress: Bool { endedAt == nil }
}

/// SQLite-backed row for the `activities` table. Dates are stored as epoch seconds.
@Table("activities")
struct ActivityRecord: Identifiable, Equatable, Sendable {
  @Column(primaryKey: true)
  var id: String
  var startedAt: Int
  var endedAt: Int?
  var createdAt: Int
}

extension Activity {
  init(record: ActivityRecord) throws {
    guard let id = UUID(uuidString: record.id) else {
      throw ActivityDatabaseError.invalidID(record.id)
    }
    self.id = id
    self.startedAt = EpochDate.decode(record.startedAt)
    self.endedAt = EpochDate.decodeOptional(record.endedAt)
    self.createdAt = EpochDate.decode(record.createdAt)
  }

  func toRecord() -> ActivityRecord {
    ActivityRecord(
      id: Self.normalizedID(id),
      startedAt: EpochDate.encode(startedAt),
      endedAt: endedAt.map(EpochDate.encode),
      createdAt: EpochDate.encode(createdAt)
    )
  }

  public static func normalizedID(_ id: UUID) -> String {
    id.uuidString.lowercased()
  }

  public static func normalizedID(_ id: String) -> String {
    id.lowercased()
  }
}
