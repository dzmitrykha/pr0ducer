import ComposableArchitecture
import Database
import Foundation
import Shared

@Reducer
public struct ActivitySessionFeature: Sendable {
  public enum SessionAction: Equatable, Sendable {
    case start
    case stop
  }

  @ObservableState
  public struct State: Equatable {
    public static let countdownDuration = 3

    public var pendingAction: SessionAction
    public var remaining: Int

    public init(
      pendingAction: SessionAction,
      remaining: Int = countdownDuration
    ) {
      self.pendingAction = pendingAction
      self.remaining = remaining
    }
  }

  public enum Action: Equatable {
    case onAppear
    case tick
    case cancelTapped
    case countdownCompleted
    case delegate(Delegate)

    public enum Delegate: Equatable {
      case finished
      case cancelled
    }
  }

  public init() {}

  private enum CancelID {
    case countdown
  }

  @Dependency(\.activityDatabase) var database
  @Dependency(\.continuousClock) var clock
  @Dependency(\.date) var date

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        return .run { send in
          for _ in 0..<State.countdownDuration {
            try await clock.sleep(for: .seconds(1))
            await send(.tick)
          }
        }
        .cancellable(id: CancelID.countdown)

      case .tick:
        state.remaining -= 1
        guard state.remaining == 0 else { return .none }
        return .send(.countdownCompleted)

      case .cancelTapped:
        return .merge(
          .cancel(id: CancelID.countdown),
          .send(.delegate(.cancelled))
        )

      case .countdownCompleted:
        return .merge(
          .cancel(id: CancelID.countdown),
          commitPendingAction(action: state.pendingAction)
        )

      case .delegate:
        return .none
      }
    }
  }

  private func commitPendingAction(action: SessionAction) -> Effect<Action> {
    .run { send in
      let now = date.now
      switch action {
      case .start:
        _ = try await database.start(now)
      case .stop:
        try await database.stop(now)
      }
      WidgetSync.reloadAllTimelines()
      await send(.delegate(.finished))
    }
  }
}
