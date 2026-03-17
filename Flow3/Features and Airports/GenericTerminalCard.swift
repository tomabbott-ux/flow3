import SwiftUI

struct GenericTerminalCard: View {

    @ObservedObject var store: LandingStore

    var terminals: [Int] {
        let terms = store.allWaitTimes()
            .filter { $0.airport == store.selectedAirport }
            .compactMap { $0.terminal }

        return Array(Set(terms)).sorted()
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("\(store.selectedAirport.rawValue) terminals")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(terminals, id: \.self) { terminal in
                    terminalRow(terminal)
                }
            }
        }
        .flowGlassCard()
    }

    func terminalRow(_ terminal: Int) -> some View {

        let minutes = store.allWaitTimes()
            .first {
                $0.airport == store.selectedAirport &&
                $0.terminal == terminal
            }?.minutes

        return HStack {

            VStack(alignment: .leading, spacing: 4) {

                Text("Terminal \(terminal)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text("Security")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            Text(minutes == nil ? "--" : "\(minutes!)m")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.10))
        )
    }
}
