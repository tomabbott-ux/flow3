import SwiftUI

struct LandingView: View {

    @ObservedObject var store: LandingStore
    @State private var selectedTerminal: Int? = nil

    // ✅ ATL selection state (mirrors JFK terminal selection concept)
    @State private var atlSelectedCheckpointName: String = "MAIN"
    @State private var atlSelectedCheckpointMinutes: Int? = nil
    @State private var atlSelectedCheckpointArea: String = "Domestic" // "Domestic" or "International"

    var body: some View {
        ZStack {
            FlowBrand.backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {

                    airportTabs

                    weatherSection

                    securityHero

                    // ✅ ATL checkpoint list (ATL only) — drives ATL hero
                    if store.selectedAirport == .atl {
                        ATLCheckpointCard(
                            selectedCheckpointName: $atlSelectedCheckpointName,
                            selectedCheckpointMinutes: $atlSelectedCheckpointMinutes,
                            selectedCheckpointArea: $atlSelectedCheckpointArea
                        )
                    }

                    if store.selectedAirport == .jfk {
                        jfkTerminals
                    }

                    if let e = store.errorText, !e.isEmpty {
                        Text(e)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .task {
            await store.refresh()

            // If we launch on JFK, default terminal 1 in the hero.
            if store.selectedAirport == .jfk {
                selectedTerminal = 1
            }

            // If we launch on ATL, default selection is Domestic MAIN (card will resolve minutes)
            if store.selectedAirport == .atl {
                atlSelectedCheckpointName = "MAIN"
                atlSelectedCheckpointMinutes = nil
                atlSelectedCheckpointArea = "Domestic"
            }

            store.startAutoRefresh() // default = every 60s (LandingStore)
        }
    }
}

// MARK: - Top airport pills

extension LandingView {

    var airportTabs: some View {
        HStack(spacing: 14) {
            airportButton("ATL", .atl)
            airportButton("JFK", .jfk)
            airportButton("LHR", .lhr)
            Spacer()
        }
    }

    func airportButton(_ title: String, _ airport: FlowAirport) -> some View {
        let isSelected = store.selectedAirport == airport

        return Button {
            store.selectedAirport = airport

            // ✅ When user clicks JFK, default terminal 1 for hero
            if airport == .jfk {
                selectedTerminal = 1
            } else {
                selectedTerminal = nil
            }

            // ✅ When user clicks ATL, default Domestic MAIN
            if airport == .atl {
                atlSelectedCheckpointName = "MAIN"
                atlSelectedCheckpointMinutes = nil
                atlSelectedCheckpointArea = "Domestic"
            }

            Task { await store.refresh() }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? FlowBrand.accent : Color.white.opacity(0.10))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(isSelected ? 0.20 : 0.12), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(isSelected ? 0.25 : 0.10), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Weather

extension LandingView {

    var weatherSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weather")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text(store.selectedAirport.rawValue.uppercased())
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.75))

            HStack(spacing: 10) {
                Image(systemName: weatherSymbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))

                Text(weatherLine)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
        .flowGlassCard()
    }

    var weatherLine: String {
        guard let w = store.weather else { return "--" }
        let temp = "\(w.temperatureC)°C"
        let cond = (w.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return cond.isEmpty ? temp : "\(temp) • \(cond)"
    }

    var weatherSymbolName: String {
        let s = (store.weather?.summary ?? "").lowercased()

        if s.contains("thunder") || s.contains("storm") { return "cloud.bolt.rain.fill" }
        if s.contains("snow") || s.contains("sleet") { return "cloud.snow.fill" }
        if s.contains("rain") || s.contains("shower") || s.contains("drizzle") { return "cloud.rain.fill" }
        if s.contains("wind") { return "wind" }
        if s.contains("fog") || s.contains("mist") || s.contains("haze") { return "cloud.fog.fill" }
        if s.contains("overcast") { return "smoke.fill" }
        if s.contains("cloud") || s.contains("partly") { return "cloud.fill" }
        if s.contains("clear") || s.contains("sun") { return "sun.max.fill" }

        return "cloud.sun.fill"
    }
}

// MARK: - Security hero

extension LandingView {

    var securityHero: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Security wait")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text(subtitleAirportLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer()

                confidenceBadge
            }

            heroCard

            Text("Updated: \(updatedText)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .flowGlassCard()
    }

    var subtitleAirportLine: String {
        switch store.selectedAirport {
        case .jfk: return "New York JFK (JFK)"
        case .atl: return "ATL (ATL)"
        case .lhr: return "London Heathrow (LHR)"
        }
    }

    // ✅ ATL hero now shows selected checkpoint name + minutes + Domestic/International
    var heroCard: some View {
        let general = heroMinutes(.general)
        let pre = heroMinutes(.precheck)

        return ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            Text(store.selectedAirport.rawValue.uppercased())
                .font(.system(size: 84, weight: .heavy))
                .foregroundColor(.white.opacity(0.06))

            if store.selectedAirport == .atl {
                let minutes = atlSelectedCheckpointMinutes ?? general
                let label = atlHeroCheckpointLabel

                VStack(spacing: 6) {
                    Text(minutes == nil ? "--" : "\(minutes!)")
                        .font(.system(size: 72, weight: .heavy))
                        .foregroundColor(.white)
                        .monospacedDigit()

                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                }
            } else {
                // ✅ JFK + LHR unchanged: two-number layout
                HStack(spacing: 34) {
                    heroMetric(value: general, label: "General")
                    heroMetric(value: pre, label: "PreCheck")
                }
            }

            // ✅ JFK terminal label stays exactly the same
            if store.selectedAirport == .jfk, let t = selectedTerminal {
                VStack {
                    Spacer()
                    Text("Terminal \(t)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.bottom, 14)
                }
            }
        }
        .frame(height: 175)
    }

    // ✅ “Domestic Main checkpoint”, “International Main checkpoint”, etc.
    var atlHeroCheckpointLabel: String {
        let area = atlSelectedCheckpointArea.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = atlSelectedCheckpointName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")

        let safeArea = area.isEmpty ? "Domestic" : area
        let safeName = name.isEmpty ? "Main" : name

        return "\(safeArea) \(safeName) checkpoint"
    }

    func heroMetric(value: Int?, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value == nil ? "--" : "\(value!)")
                .font(.system(size: 58, weight: .heavy))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
        }
    }

    func heroMinutes(_ queue: QueueType) -> Int? {
        if store.selectedAirport == .jfk {
            // If JFK selected and terminal not set, default to 1 automatically
            let t = selectedTerminal ?? 1
            return store.jfkMinutes(terminal: t, category: queue)
        }
        return store.overallMinutes(queue)
    }
}

// MARK: - JFK terminals list (UNCHANGED)

extension LandingView {

    var jfkTerminals: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("JFK terminals")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(store.jfkTerminalsPresent(), id: \.self) { terminal in
                    terminalRow(terminal)
                }
            }
        }
        .flowGlassCard()
        .onAppear {
            if selectedTerminal == nil {
                selectedTerminal = 1
            }
        }
    }

    func terminalRow(_ terminal: Int) -> some View {
        let general = store.jfkMinutes(terminal: terminal, category: .general)
        let pre = store.jfkMinutes(terminal: terminal, category: .precheck)
        let isSelected = selectedTerminal == terminal

        return Button {
            selectedTerminal = terminal
        } label: {
            HStack(spacing: 14) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("Terminal \(terminal)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Security")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }

                Spacer()

                HStack(spacing: 10) {
                    queuePill(title: "General", value: general)
                    queuePill(title: "PreCheck", value: pre)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? FlowBrand.accent.opacity(0.22) : Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(isSelected ? 0.18 : 0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    func queuePill(title: String, value: Int?) -> some View {
        VStack(spacing: 4) {
            Text(value == nil ? "--" : "\(value!)m")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text(title)
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
}

// MARK: - Updated + Confidence

extension LandingView {

    var updatedText: String {
        guard let date = store.lastUpdated else { return "--" }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy h:mm a"
        return f.string(from: date)
    }

    var confidenceBadge: some View {
        let c = confidence

        return Text("Confidence \(c.label)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(c.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
    }

    var confidence: (label: String, color: Color) {
        guard let last = store.lastUpdated else { return ("Low", .red) }
        let age = Date().timeIntervalSince(last)

        if age < 120 { return ("High", .green) }
        if age < 300 { return ("Medium", .orange) }
        return ("Low", .red)
    }
}

// MARK: - Flow Brand + helpers (MUST be file-scope)

private enum FlowBrand {
    static let accent = Color(hex: "8B5CF6")
    static let backgroundTop = Color(hex: "2A0C5A")
    static let backgroundMid = Color(hex: "3B136E")
    static let backgroundBottom = Color(hex: "14062F")

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [backgroundTop, backgroundMid, backgroundBottom]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension View {
    func flowGlassCard() -> some View {
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
