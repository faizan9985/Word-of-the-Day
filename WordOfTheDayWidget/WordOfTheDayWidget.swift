// Target membership: WordOfTheDayWidgetExtension only

import SwiftUI
import WidgetKit

struct WordOfTheDayWidget: Widget {
    let kind = "WordOfTheDayLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordTimelineProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                LockScreenWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                LockScreenWidgetView(entry: entry)
                    .padding()
            }
        }
        .configurationDisplayName("Word of the Day")
        .description("See today's vocabulary word on your Lock Screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}
