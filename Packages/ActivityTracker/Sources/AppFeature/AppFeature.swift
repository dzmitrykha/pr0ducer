import ComposableArchitecture
import DayListFeature
import Shared
import SwiftUI

@Reducer
public struct AppFeature: Sendable {
  @ObservableState
  public struct State: Equatable {
    public var dayList = DayListFeature.State()
    public var selectedDay: DayCard?

    public init(
      dayList: DayListFeature.State = DayListFeature.State(),
      selectedDay: DayCard? = nil
    ) {
      self.dayList = dayList
      self.selectedDay = selectedDay
    }
  }

  public enum Action: Equatable {
    case onAppear
    case scenePhaseChanged(ScenePhase)
    case deepLink(URL)
    case dayList(DayListFeature.Action)
  }

  public init() {}

  @Dependency(\.pendingActionStore) var pendingActionStore

  public var body: some ReducerOf<Self> {
    Scope(state: \.dayList, action: \.dayList) {
      DayListFeature()
    }

    Reduce { state, action in
      switch action {
      case .onAppear:
        return .merge(
          resolvePendingAction(),
          .send(.dayList(.refresh))
        )

      case let .scenePhaseChanged(phase):
        guard phase == .active else { return .none }
        return .merge(
          resolvePendingAction(),
          .send(.dayList(.refresh))
        )

      case let .deepLink(url):
        guard let deepLink = DeepLink(url: url) else { return .none }
        return handle(deepLink: deepLink)

      case let .dayList(.dayCardTapped(card)):
        state.selectedDay = card
        return .none

      case .dayList:
        return .none
      }
    }
  }

  private func handle(deepLink: DeepLink) -> Effect<Action> {
    switch deepLink {
    case .open:
      return .send(.dayList(.refresh))
    }
  }

  private func resolvePendingAction() -> Effect<Action> {
    .run { [pendingActionStore] send in
      guard let pending = pendingActionStore.consume() else { return }
      await send(.deepLink(pending.deepLink.url))
    }
  }
}

#if DEBUG
  extension AppFeature {
    public static func debug() -> some Reducer<State, Action> {
      Self()._printChanges()
    }
  }
#endif
