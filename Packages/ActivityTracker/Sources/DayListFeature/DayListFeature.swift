import ComposableArchitecture
import Database
import Foundation

@Reducer
public struct DayListFeature: Sendable {
  @ObservableState
  public struct State: Equatable {
    public var cards: [DayCard] = []
    public var isLoading = false
    public var dayWindow: Int = DayCardModel.defaultDayWindow
    public var referenceDate: Date = .distantPast

    public init(
      cards: [DayCard] = [],
      isLoading: Bool = false,
      dayWindow: Int = DayCardModel.defaultDayWindow,
      referenceDate: Date = .distantPast
    ) {
      self.cards = cards
      self.isLoading = isLoading
      self.dayWindow = dayWindow
      self.referenceDate = referenceDate
    }
  }

  public enum Action: Equatable {
    case onAppear
    case refresh
    case loadOlderDays
    case dayCardTapped(DayCard)
    case cardsLoaded([DayCard], referenceDate: Date)
    case loadFailed
  }

  public init() {}

  @Dependency(\.activityDatabase) var database
  @Dependency(\.calendar) var calendar
  @Dependency(\.date) var date

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear, .refresh:
        state.isLoading = true
        return loadCards(dayWindow: state.dayWindow)

      case .loadOlderDays:
        guard !state.isLoading else { return .none }
        state.dayWindow += DayCardModel.olderDaysBatchSize
        state.isLoading = true
        return loadCards(dayWindow: state.dayWindow)

      case let .cardsLoaded(cards, referenceDate):
        state.isLoading = false
        state.cards = cards
        state.referenceDate = referenceDate
        return .none

      case .loadFailed:
        state.isLoading = false
        return .none

      case .dayCardTapped:
        return .none
      }
    }
  }

  private func loadCards(dayWindow: Int) -> Effect<Action> {
    .run { send in
      do {
        let now = date.now
        let todayStart = calendar.startOfDay(for: now)
        guard
          let windowStart = calendar.date(byAdding: .day, value: -(dayWindow - 1), to: todayStart),
          let windowEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)
        else {
          await send(.loadFailed)
          return
        }

        let activities = try await database.activities(windowStart, windowEnd)
        let cards = makeDayCards(
          activities: activities,
          calendar: calendar,
          now: now,
          dayCount: dayWindow
        )
        await send(.cardsLoaded(cards, referenceDate: now))
      } catch {
        await send(.loadFailed)
      }
    }
  }
}
