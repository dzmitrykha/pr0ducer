import Foundation

/// Converts between `Date` and INTEGER epoch seconds stored in SQLite.
enum EpochDate {
  static func encode(_ date: Date) -> Int {
    Int(date.timeIntervalSince1970)
  }

  static func decode(_ seconds: Int) -> Date {
    Date(timeIntervalSince1970: TimeInterval(seconds))
  }

  static func decodeOptional(_ seconds: Int?) -> Date? {
    seconds.map(decode)
  }
}
