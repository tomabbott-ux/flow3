import SwiftUI

struct ATLCheckpointCard: View {
    @Binding var selectedCheckpointName: String
    @Binding var selectedCheckpointMinutes: Int?
    @Binding var selectedCheckpointArea: String

    @State private var domestic: [ATLSecurityCheckpointWait] = []
    @State private var intl: [ATLSecurityCheckpointWait] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let provider = ATLLiveWaitTimeProvider()

    // ✅ Auto refresh ATL every 60 seconds (same cadence as LandingStore)
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text("ATL checkpoints")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(.white.opacity(0.85))
                        .scaleEffect(0.9)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
            }

            if domestic.isEmpty && intl.isEmpty && errorMessage == nil {
                Text("Loading checkpoint times…")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.65))
            }

            if !domestic.isEmpty {
                Text("Domestic")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))

                VStack(spacing: 12) {
                    ForEach(domestic) { item in
                        checkpointRow(item, area: "Domestic")
                    }
                }
            }

            if !intl.isEmpty {
                Text("International")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.top, 2)

                VStack(spacing: 12) {
                    ForEach(intl) { item in
                        checkpointRow(item, area: "International")
                    }
                }
            }
        }
        .atlGlassCard()
        .task { await load() }
        .onReceive(timer) { _ in
            Task { await load() }
        }
    }

    // MARK: - Row (tap to select — like JFK terminals)

    private func checkpointRow(_ item: ATLSecurityCheckpointWait, area: String) -> some View {
        let nameUpper = item.checkpointName.uppercased()
        let isSouth = nameUpper.contains("SOUTH")

        let isSelected =
            normalize(area) == normalize(selectedCheckpointArea) &&
            normalize(nameUpper) == normalize(selectedCheckpointName)

        return Button {
            selectedCheckpointArea = area
            selectedCheckpointName = nameUpper
            selectedCheckpointMinutes = item.minutes
        } label: {
            HStack(spacing: 14) {

                VStack(alignment: .leading, spacing: 4) {

                    Text(nameUpper)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    if isSouth {
                        Text("PreCheck Only Checkpoint")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                    }
                }

                Spacer()

                timePill(value: item.minutes, label: isSouth ? "PreCheck" : "Wait")

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? atlAccent.opacity(0.22) : Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(isSelected ? 0.18 : 0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func timePill(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)m")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .monospacedDigit()

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(width: 78, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    // MARK: - Load

    private func load() async {
        if domestic.isEmpty && intl.isEmpty { isLoading = true }
        errorMessage = nil

        do {
            let items = try await provider.fetch()
            domestic = items.filter { $0.terminal == .domestic }
            intl = items.filter { $0.terminal == .international }

            // ✅ Default selection: DOMESTIC MAIN if present
            applyDefaultSelectionIfNeeded(domestic: domestic, intl: intl)

            // ✅ Keep selected minutes in sync if the selected checkpoint still exists
            syncSelectionMinutes(domestic: domestic, intl: intl)

        } catch {
            domestic = []
            intl = []
            errorMessage = "Couldn’t load ATL checkpoints."
            print("ATLCheckpointCard load error:", error)
        }

        isLoading = false
    }

    private func applyDefaultSelectionIfNeeded(domestic: [ATLSecurityCheckpointWait], intl: [ATLSecurityCheckpointWait]) {
        // Only apply default if we have no selection minutes yet
        if selectedCheckpointMinutes != nil { return }

        if let mainDomestic = domestic.first(where: { $0.checkpointName.uppercased().contains("MAIN") }) {
            selectedCheckpointArea = "Domestic"
            selectedCheckpointName = mainDomestic.checkpointName.uppercased()
            selectedCheckpointMinutes = mainDomestic.minutes
            return
        }

        let all = domestic.map { ("Domestic", $0) } + intl.map { ("International", $0) }
        if let anyMain = all.first(where: { $0.1.checkpointName.uppercased().contains("MAIN") }) {
            selectedCheckpointArea = anyMain.0
            selectedCheckpointName = anyMain.1.checkpointName.uppercased()
            selectedCheckpointMinutes = anyMain.1.minutes
            return
        }

        if let firstDomestic = domestic.first {
            selectedCheckpointArea = "Domestic"
            selectedCheckpointName = firstDomestic.checkpointName.uppercased()
            selectedCheckpointMinutes = firstDomestic.minutes
            return
        }

        if let firstIntl = intl.first {
            selectedCheckpointArea = "International"
            selectedCheckpointName = firstIntl.checkpointName.uppercased()
            selectedCheckpointMinutes = firstIntl.minutes
            return
        }
    }

    private func syncSelectionMinutes(domestic: [ATLSecurityCheckpointWait], intl: [ATLSecurityCheckpointWait]) {
        let targetArea = normalize(selectedCheckpointArea)
        let targetName = normalize(selectedCheckpointName)

        let list = (targetArea == "DOMESTIC") ? domestic : intl
        if let match = list.first(where: { normalize($0.checkpointName) == targetName }) {
            selectedCheckpointMinutes = match.minutes
        }
    }

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var atlAccent: Color { Color(hex: "8B5CF6") }
}

// MARK: - Local glass card (matches LandingView.flowGlassCard look)

private extension View {
    func atlGlassCard() -> some View {
        self
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        case 8:
            (a, r, g, b) = ((int >> 24) & 255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
