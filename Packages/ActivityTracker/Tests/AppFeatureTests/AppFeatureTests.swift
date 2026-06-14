import AppFeature
import ActivitySessionFeature
import ComposableArchitecture
import CustomDump
import Database
import DayListFeature
import Dependencies
import DependenciesTestSupport
import Foundation
import Shared
import Testing

@Suite(.serialized)
@MainActor
struct AppFeatureTests {
  @Test func deepLinkOpenRefreshesDayList() async {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    let database = try! DatabaseBootstrap.inMemory()
    let client = ActivityDatabase.live(database: database)

    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.activityDatabase = client
      $0.calendar = makeCalendar()
      $0.timeZone = makeCalendar().timeZone
      $0.date.now = fixedDate
      $0.pendingActionStore = .testValue
    }
    store.exhaustivity = .off

    await store.send(.deepLink(URL(string: "activitytracker://open")!))
    await store.receive(\.dayList.refresh) {
      $0.dayList.isLoading = true
    }
    await store.receive(\.dayList.cardsLoaded) {
      $0.dayList.isLoading = false
      $0.dayList.referenceDate = fixedDate
    }
  }

  @Test func scenePhaseActiveRefreshesDayList() async {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    let database = try! DatabaseBootstrap.inMemory()
    let client = ActivityDatabase.live(database: database)

    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.activityDatabase = client
      $0.calendar = makeCalendar()
      $0.timeZone = makeCalendar().timeZone
      $0.date.now = fixedDate
      $0.pendingActionStore = .testValue
    }
    store.exhaustivity = .off

    await store.send(.scenePhaseChanged(.active))
    await store.receive(\.dayList.refresh) {
      $0.dayList.isLoading = true
    }
    await store.receive(\.dayList.cardsLoaded) {
      $0.dayList.isLoading = false
      $0.dayList.referenceDate = fixedDate
    }
  }

  @Test func pendingActionResolvedOnActive() async {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    let database = try! DatabaseBootstrap.inMemory()
    let client = ActivityDatabase.live(database: database)
    let pendingStore = LockIsolated<PendingAction?>(.open)

    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.activityDatabase = client
      $0.calendar = makeCalendar()
      $0.timeZone = makeCalendar().timeZone
      $0.date.now = fixedDate
      $0.pendingActionStore = PendingActionStore(
        save: { action in pendingStore.setValue(action) },
        consume: {
          let action = pendingStore.value
          pendingStore.setValue(nil)
          return action
        }
      )
    }
    store.exhaustivity = .off

    await store.send(.onAppear)
    await store.skipReceivedActions()

    #expect(pendingStore.value == nil)
    #expect(store.state.dayList.referenceDate == fixedDate)
  }

  @Test func dayCardTapStoresSelectedDay() async {
    let card = DayCard(
      date: makeDate(year: 2026, month: 6, day: 14, hour: 0),
      count: 2,
      segments: []
    )

    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.pendingActionStore = .testValue
    }

    await store.send(.dayList(.dayCardTapped(card))) {
      $0.selectedDay = card
    }
  }

  @Test func pendingConfirmStartPresentsSession() async {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    let database = try! DatabaseBootstrap.inMemory()
    let client = ActivityDatabase.live(database: database)
    let pendingStore = LockIsolated<PendingAction?>(.confirmStart)

    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.activityDatabase = client
      $0.calendar = makeCalendar()
      $0.timeZone = makeCalendar().timeZone
      $0.date.now = fixedDate
      $0.pendingActionStore = PendingActionStore(
        save: { action in pendingStore.setValue(action) },
        consume: {
          let action = pendingStore.value
          pendingStore.setValue(nil)
          return action
        }
      )
    }
    store.exhaustivity = .off

    await store.send(.onAppear)
    await store.skipReceivedActions()

    #expect(store.state.session?.pendingAction == .start)
  }

  @Test func sessionFinishedRefreshesDayList() async {
    let fixedDate = makeDate(year: 2026, month: 6, day: 14, hour: 10)
    let database = try! DatabaseBootstrap.inMemory()
    let client = ActivityDatabase.live(database: database)
    let clock = TestClock()

    let store = TestStore(
      initialState: AppFeature.State(
        session: ActivitySessionFeature.State(pendingAction: .start)
      )
    ) {
      AppFeature()
    } withDependencies: {
      $0.activityDatabase = client
      $0.calendar = makeCalendar()
      $0.timeZone = makeCalendar().timeZone
      $0.date.now = fixedDate
      $0.continuousClock = clock
      $0.pendingActionStore = .testValue
    }
    store.exhaustivity = .off

    await store.send(.session(.presented(.onAppear)))
    await clock.advance(by: .seconds(ActivitySessionFeature.State.countdownDuration))
    await store.skipReceivedActions()

    #expect(store.state.session == nil)
    #expect(store.state.dayList.isLoading == false)
  }

  @Test func deepLinkParserRecognizesOpenRoute() {
    let url = URL(string: "activitytracker://open")!
    #expect(DeepLink(url: url) == .open)
    #expect(DeepLink(url: URL(string: "other://open")!) == nil)
  }
}

// MARK: - Helpers

private func makeCalendar() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0)!
  return calendar
}

private func makeDate(
  year: Int,
  month: Int,
  day: Int,
  hour: Int
) -> Date {
  makeCalendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}
