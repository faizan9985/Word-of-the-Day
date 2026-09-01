// Target membership: WordOfTheDayWidgetExtension only

import SwiftUI
import WidgetKit

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordTimelineEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Word: \(entry.wordEntry.word)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.wordEntry.word)
                    .font(.headline)
                    .bold()
                    .lineLimit(1)
                Text(entry.wordEntry.definition)
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text(entry.wordEntry.word)
        }
    }
}
