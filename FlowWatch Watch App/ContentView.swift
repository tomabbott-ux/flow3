import SwiftUI

struct ContentView: View {
    var body: some View {
        WatchRootView()
            .onAppear {
                print("⌚️ Watch ContentView appeared")
            }
    }
}

#Preview {
    ContentView()
}
