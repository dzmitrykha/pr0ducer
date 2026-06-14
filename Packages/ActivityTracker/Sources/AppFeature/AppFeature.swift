import ActivitySessionFeature
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
    @Presents public var session: ActivitySessionFeature.State?

    public init(
      dayList: DayListFeature.State = DayListFeature.State(),
      selectedDay: DayCard? = nil,
      session: ActivitySessionFeature.State? = nil
    ) {
      self.dayList = dayList
      self.selectedDay = selectedDay
      self.session = session
    }
  }

  public enum Action: Equatable {
    case onAppear
    case scenePhaseChanged(ScenePhase)
    case deepLink(URL)
    case presentSession(ActivitySessionFeature.SessionAction)
    case dayList(DayListFeature.Action)
    case session(PresentationAction<ActivitySessionFeature.Action>)
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

      case let .presentSession(sessionAction):
        state.session = ActivitySessionFeature.State(pendingAction: sessionAction)
        return .none

      case let .dayList(.dayCardTapped(card)):
        state.selectedDay = card
        return .none

      case .session(.presented(.delegate(.finished))):
        return .merge(
          .send(.dayList(.refresh)),
          .send(.session(.dismiss))
        )

      case .session(.presented(.delegate(.cancelled))):
        return .send(.session(.dismiss))

      case .dayList, .session:
        return .none
      }
    }
    .ifLet(\.$session, action: \.session) {
      ActivitySessionFeature()
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
      switch pending {
      case .open:
        await send(.deepLink(DeepLink.open.url))
      case .confirmStart:
        await send(.presentSession(.start))
      case .confirmStop:
        await send(.presentSession(.stop))
      }
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
