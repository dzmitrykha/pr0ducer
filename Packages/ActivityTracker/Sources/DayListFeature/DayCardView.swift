import Shared
import SwiftUI

/// One day row: activity count on the left, 0–24h track on the right.
public struct DayCardView: View {
  private enum Layout {
    /// Fixed width so the hour track stays the same size for 1- and 2-digit counts.
    static let countColumnWidth: CGFloat = 28
  }

  private let card: DayCard
  private let calendar: Calendar
  private let referenceDate: Date

  public init(card: DayCard, calendar: Calendar, referenceDate: Date) {
    self.card = card
    self.calendar = calendar
    self.referenceDate = referenceDate
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(dayTitle)
        .font(.caption2)
        .foregroundStyle(.secondary)

      HStack(alignment: .center, spacing: 6) {
        Text(WidgetSnapshot.countDisplayText(for: card.count))
          .font(.system(size: 22, weight: .bold, design: .rounded))
          .monospacedDigit()
          .frame(width: Layout.countColumnWidth, alignment: .trailing)

        HourTrackView(segments: card.segments)
          .frame(maxWidth: .infinity)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(.isButton)
    .accessibilityHint("Opens day details")
  }

  private var dayTitle: String {
    if calendar.isDate(card.date, inSameDayAs: referenceDate) {
      return "Today"
    }
    if
      let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: referenceDate)),
      calendar.isDate(card.date, inSameDayAs: yesterday)
    {
      return "Yesterday"
    }
    return Self.shortDateFormatter(calendar: calendar).string(from: card.date)
  }

  private var accessibilityLabel: String {
    let segmentCount = card.segments.count
    return "\(dayTitle), \(card.count) activities, \(segmentCount) segments on timeline"
  }

  private static func shortDateFormatter(calendar: Calendar) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate("MMMd")
    return formatter
  }
}
