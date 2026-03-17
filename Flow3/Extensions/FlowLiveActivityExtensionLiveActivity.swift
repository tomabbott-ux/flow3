//
//  FlowLiveActivityExtensionLiveActivity.swift
//  FlowLiveActivityExtension
//
//  Created by Tom Abbott on 16/03/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FlowLiveActivityExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FlowLiveActivityExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlowLiveActivityExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FlowLiveActivityExtensionAttributes {
    fileprivate static var preview: FlowLiveActivityExtensionAttributes {
        FlowLiveActivityExtensionAttributes(name: "World")
    }
}

extension FlowLiveActivityExtensionAttributes.ContentState {
    fileprivate static var smiley: FlowLiveActivityExtensionAttributes.ContentState {
        FlowLiveActivityExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FlowLiveActivityExtensionAttributes.ContentState {
         FlowLiveActivityExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FlowLiveActivityExtensionAttributes.preview) {
   FlowLiveActivityExtensionLiveActivity()
} contentStates: {
    FlowLiveActivityExtensionAttributes.ContentState.smiley
    FlowLiveActivityExtensionAttributes.ContentState.starEyes
}
