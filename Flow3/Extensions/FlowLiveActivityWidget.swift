import ActivityKit
import WidgetKit
import SwiftUI

struct FlowLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlowActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text(context.state.airportCode)
                    .font(.headline)

                Text(context.state.securityText)
                    .font(.title2)
                    .bold()

                Text("Leave \(context.state.leaveTimeText)")
                    .font(.subheadline)

                Text(context.state.checkpointText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.airportCode)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.securityText)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Leave \(context.state.leaveTimeText)")
                        Text(context.state.checkpointText)
                            .font(.caption)
                    }
                }
            } compactLeading: {
                Text(context.state.airportCode)
            } compactTrailing: {
                Text(context.state.securityText)
            } minimal: {
                Text(context.state.airportCode)
            }
        }
    }
}
