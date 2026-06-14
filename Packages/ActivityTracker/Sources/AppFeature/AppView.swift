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
    .onAppear {
      store.send(.onAppear)
    }
  }
}
