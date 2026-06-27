import CustomDump
import Database
import DayListFeature
import Foundation
import Shared
import Testing

@Suite
struct DayCardModelTests {
  @Test func singleActivityProducesOneSegment() {
    let calendar = makeCalendar()
    let day = makeDate(year: 2026, month: 6, day: 14, hour: 0, calendar: calendar)
    let activity = Activity(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      startedAt: makeDate(year: 2026, month: 6, day: 14, hour: 10, calendar: calendar),
      endedAt: makeDate(year: 2026, month: 6, day: 14, hour: 12, calendar: calendar),
      createdAt: makeDate(year: 2026, month: 6, day: 14, hour: 10, calendar: calendar)
    )
    let now = makeDate(year: 2026, month: 6, day: 14, hour: 15, calendar: calendar)

    let cards = makeDayCards(activities: [activity], calendar: calendar, now: now, dayCount: 1)

    #expect(cards.count == 1)
    #expect(cards[0].date == day)
    #expect(cards[0].count == 1)
    #expect(cards[0].segments.count == 1)
    #expect(cards[0].segments[0].start.isApproximatelyEqual(to: 10.0 / 24.0))
    #expect(cards[0].segments[0].end.isApproximatelyEqual(to: 12.0 / 24.0))
    #expect(cards[0].segments[0].isInProgress == false)
  }

  @Test func midnightSpanningActivitySplitsAcrossAdjacentDays() {
    let calendar = makeCalendar()
    let firstDay = makeDate(year: 2026, month: 6, day: 14, hour: 0, calendar: calendar)
    let secondDay = makeDate(year: 2026, month: 6, day: 15, hour: 0, calendar: calendar)
    let activity = Activity(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
      startedAt: makeDate(year: 2026, month: 6, day: 14, hour: 23, minute: 30, calendar: calendar),
      endedAt: makeDate(year: 2026, month: 6, day: 15, hour: 0, minute: 30, calendar: calendar),
      createdAt: makeDate(year: 2026, month: 6, day: 14, hour: 23, minute: 30, calendar: calendar)
    )
    let now = makeDate(year: 2026, month: 6, day: 15, hour: 8, calendar: calendar)

    let cards = makeDayCards(activities: [activity], calendar: calendar, now: now, dayCount: 2)

    #expect(cards.count == 2)
    #expect(cards[0].date == secondDay)
    #expect(cards[1].date == firstDay)

    #expect(cards[1].count == 1)
    // swiftlint:disable:next empty_count
    #expect(cards[0].count == 0)

    #expect(cards[1].segments.count == 1)
    #expect(cards[1].segments[0].start.isApproximatelyEqual(to: 23.5 / 24.0))
    #expect(cards[1].segments[0].end.isApproximatelyEqual(to: 1.0))

    #expect(cards[0].segments.count == 1)
    #expect(cards[0].segments[0].start.isApproximatelyEqual(to: 0.0))
    #expect(cards[0].segments[0].end.isApproximatelyEqual(to: 0.5 / 24.0))
  }

  @Test func inProgressActivityEndsAtNowAndIsFlagged() {
    let calendar = makeCalendar()
    let activity = Activity(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
      startedAt: makeDate(year: 2026, month: 6, day: 14, hour: 9, calendar: calendar),
      endedAt: nil,
      createdAt: makeDate(year: 2026, month: 6, day: 14, hour: 9, calendar: calendar)
    )
    let now = makeDate(year: 2026, month: 6, day: 14, hour: 11, calendar: calendar)

    let cards = makeDayCards(activities: [activity], calendar: calendar, now: now, dayCount: 1)

    #expect(cards[0].count == 1)
    #expect(cards[0].segments.count == 1)
    #expect(cards[0].segments[0].end.isApproximatelyEqual(to: 11.0 / 24.0))
    #expect(cards[0].segments[0].isInProgress == true)
  }

  @Test func countMatchesActivitiesStartedThatDay() {
    let calendar = makeCalendar()
    let day = makeDate(year: 2026, month: 6, day: 14, hour: 0, calendar: calendar)
    let startedToday = Activity(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
      startedAt: makeDate(year: 2026, month: 6, day: 14, hour: 8, calendar: calendar),
      endedAt: makeDate(year: 2026, month: 6, day: 14, hour: 9, calendar: calendar),
      createdAt: makeDate(year: 2026, month: 6, day: 14, hour: 8, calendar: calendar)
    )
    let startedYesterdayEndsToday = Activity(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
      startedAt: makeDate(year: 2026, month: 6, day: 13, hour: 22, calendar: calendar),
      endedAt: makeDate(year: 2026, month: 6, day: 14, hour: 1, calendar: calendar),
      createdAt: makeDate(year: 2026, month: 6, day: 13, hour: 22, calendar: calendar)
    )
    let now = makeDate(year: 2026, month: 6, day: 14, hour: 12, calendar: calendar)

    let cards = makeDayCards(
      activities: [startedToday, startedYesterdayEndsToday],
      calendar: calendar,
      now: now,
      dayCount: 1
    )

    #expect(cards[0].date == day)
    #expect(cards[0].count == 1)
    #expect(cards[0].segments.count == 2)
  }

  @Test func emptyDayShowsZeroCountAndNoSegments() {
    let calendar = makeCalendar()
    let now = makeDate(year: 2026, month: 6, day: 14, hour: 12, calendar: calendar)

    let cards = makeDayCards(activities: [], calendar: calendar, now: now, dayCount: 3)

    #expect(cards.count == 3)
    #expect(cards.allSatisfy { $0.isEmpty })
  }

  @Test func isEmptyIsTrueForZeroActivityDay() {
    let calendar = makeCalendar()
    let day = makeDate(year: 2026, month: 6, day: 14, hour: 0, calendar: calendar)
    let card = DayCard(date: day, count: 0, segments: [])

    #expect(card.isEmpty)
  }

  @Test func isEmptyIsFalseForDayWithActivities() {
    let calendar = makeCalendar()
    let day = makeDate(year: 2026, month: 6, day: 14, hour: 0, calendar: calendar)
    let segment = ActivitySegment(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
      start: 0.25,
      end: 0.5,
      isInProgress: false
    )
    let card = DayCard(date: day, count: 1, segments: [segment])

    #expect(!card.isEmpty)
  }
}

// MARK: - Helpers

private extension Double {
  func isApproximatelyEqual(to other: Double, tolerance: Double = 0.0001) -> Bool {
    Swift.abs(self - other) <= tolerance
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
  minute: Int = 0,
  calendar: Calendar? = nil
) -> Date {
  let calendar = calendar ?? makeCalendar()
  return calendar.date(
    from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
  )!
}
