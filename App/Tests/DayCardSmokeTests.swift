import Shared
import XCTest

final class ActivityTrackerSmokeTests: XCTestCase {
  func testDeepLinkOpenRouteParses() {
    let url = URL(string: "activitytracker://open")!
    XCTAssertEqual(DeepLink(url: url), .open)
  }
}
