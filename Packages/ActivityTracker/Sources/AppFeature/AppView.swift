import ActivitySessionFeature
import ComposableArchitecture
import DayListFeature
import SwiftUI

public struct AppView: View {
  let store: StoreOf<AppFeature>

  public init(store: StoreOf<AppFeature>) {
    self.store = store
  }

  public var body: some View {
    DayListView(
      store: store.scope(state: \.dayList, action: \.dayList)
    )
    .sheet(
      isPresented: Binding(
        get: { store.session != nil },
        set: { isPresented in
          if !isPresented {
            store.send(.session(.dismiss))
          }
        }
      )
    ) {
      if let sessionStore = store.scope(state: \.session, action: \.session.presented) {
        ActivitySessionView(store: sessionStore)
      }
    }
    .onAppear {
      store.send(.onAppear)
    }
  }
}
