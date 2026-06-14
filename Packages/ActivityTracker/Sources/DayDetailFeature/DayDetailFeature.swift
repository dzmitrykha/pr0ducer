import ComposableArchitecture
import Database
import Foundation
import Shared

@Reducer
public struct DayDetailFeature: Sendable {
  @ObservableState
  public struct State: Equatable, Identifiable {
    public var dayStart: Date
    public var referenceDate: Date
    public var intervals: [DayActivityInterval] = []
    public var isLoading = false

    public var id: Date { dayStart }

    public init(dayStart: Date, referenceDate: Date) {
      self.dayStart = dayStart
      self.referenceDate = referenceDate
    }
  }

  public enum Action: Equatable {
    case onAppear
    case refresh
    case delete(UUID)
    case intervalsLoaded([DayActivityInterval], referenceDate: Date)
    case loadFailed
    case deleteFailed
    case delegate(Delegate)

    public enum Delegate: Equatable {
      case dataChanged
    }
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
        return loadIntervals(dayStart: state.dayStart)

      case let .intervalsLoaded(intervals, referenceDate):
        state.isLoading = false
        state.intervals = intervals
        state.referenceDate = referenceDate
        return .none

      case .loadFailed, .deleteFailed:
        state.isLoading = false
        return .none

      case let .delete(id):
        return .run { send in
          do {
            try await database.delete(id)
            WidgetSync.reloadAllTimelines()
            await send(.delegate(.dataChanged))
            await send(.refresh)
          } catch {
            await send(.deleteFailed)
          }
        }

      case .delegate:
        return .none
      }
    }
  }

  private func loadIntervals(dayStart: Date) -> Effect<Action> {
    .run { send in
      do {
        let now = date.now
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
          await send(.loadFailed)
          return
        }

        let activities = try await database.activities(dayStart, dayEnd)
        let intervals = makeDayActivityIntervals(
          activities: activities,
          calendar: calendar,
          now: now,
          dayStart: dayStart
        )
        await send(.intervalsLoaded(intervals, referenceDate: now))
      } catch {
        await send(.loadFailed)
      }
    }
  }
}
