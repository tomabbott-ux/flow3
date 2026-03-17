import SwiftUI

struct LHRCheckpointCard: View {
    @ObservedObject var store: LandingStore
    @Binding var selectedTerminal: Int?

    var body: some View {
        EmptyView()
    }
}
