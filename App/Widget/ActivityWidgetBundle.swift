import ActivityIntents
import SwiftUI
import WidgetKit

@main
struct ActivityWidgetBundle: WidgetBundle {
  init() {
    IntentDependencies.bootstrap()
  }

  var body: some Widget {
    ToggleActivityComplication()
    OpenAppComplication()
  }
}
