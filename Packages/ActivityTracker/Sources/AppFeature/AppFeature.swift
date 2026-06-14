import ActivitySessionFeature
import ComposableArchitecture
import DayDetailFeature
import DayListFeature
import Shared
import SwiftUI

@Reducer
public struct AppFeature: Sendable {
  @ObservableState
  public struct State: Equatable {
    public var dayList = DayListFeature.State()
    public var dayDetail: DayDetailFeature.State?
    @Presents public var session: ActivitySessionFeature.State?

    public init(
      dayList: DayListFeature.State = DayListFeature.State(),
      dayDetail: DayDetailFeature.State? = nil,
      session: ActivitySessionFeature.State? = nil
    ) {
      self.dayList = dayList
      self.dayDetail = dayDetail
      self.session = session
    }
  }

  public enum Action: Equatable {
    case onAppear
    case scenePhaseChanged(ScenePhase)
    case deepLink(URL)
    case presentSession(ActivitySessionFeature.SessionAction)
    case dayList(DayListFeature.Action)
    case dayDetail(DayDetailFeature.Action)
    case dayDetailDismissed
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
        state.dayDetail = DayDetailFeature.State(
          dayStart: card.date,
          referenceDate: state.dayList.referenceDate
        )
        return .none

      case .dayDetail(.delegate(.dataChanged)):
        return .send(.dayList(.refresh))

      case .dayDetailDismissed:
        state.dayDetail = nil
        return .none

      case .session(.presented(.delegate(.finished))):
        return .merge(
          .send(.dayList(.refresh)),
          .send(.session(.dismiss))
        )

      case .session(.presented(.delegate(.cancelled))):
        return .send(.session(.dismiss))

      case .dayList, .dayDetail, .session:
        return .none
      }
    }
    .ifLet(\.dayDetail, action: \.dayDetail) {
      DayDetailFeature()
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
