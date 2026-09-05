// Target membership: WordOfTheDayWidgetExtension only

import SwiftUI
import WidgetKit

struct WordOfTheDayWidget: Widget {
    let kind = "WordOfTheDayLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordTimelineProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Word of the Day")
        .description("See today's vocabulary word on your Lock Screen or Home Screen.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular,
            .systemSmall,
            .systemMedium
        ])
    }
}
