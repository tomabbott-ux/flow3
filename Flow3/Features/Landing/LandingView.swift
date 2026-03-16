import SwiftUI

struct LandingView: View {

    @ObservedObject var store: LandingStore
    @State private var selectedRowID: String? = nil
    @State private var now = Date()
    @State private var isShowingAirportSelector = false
    @State var isShowingDeparturePlanner = false

    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let updatedTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var displayRows: [AirportDisplayRow] {
        store.displayRowsForSelectedAirport()
    }

    private var selectedRow: AirportDisplayRow? {
        if let selectedRowID {
            return displayRows.first(where: { $0.id == selectedRowID }) ?? displayRows.first
        }
        return displayRows.first
    }

    private var usesAverageWaitPresentation: Bool {
        AirportRegistry.definition(for: store.selectedAirport)?.feedType == .highConfidence
    }

    private var confidenceLevel: FlowConfidenceLevel {

        guard let definition = AirportRegistry.definition(for: store.selectedAirport) else {
            return .comingSoon
        }

        switch definition.feedType {
        case .live:
            return .live
        case .highConfidence:
            return .highConfidence
        case .estimated:
            return .lowConfidence
        case .comingSoon:
            return .comingSoon
        }
    }

    var body: some View {
        ZStack {
            FlowBrand.backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    airportSelectorPill
                    headerSection
                    weatherRow

                    if store.trackedFlight != nil {
                        TrackedFlightPill(store: store)
                    }

                    securityHero

                    departurePlannerButton

                    GenericAirportBreakdownCard(
                        store: store,
                        selectedRowID: $selectedRowID
                    )

                    errorSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingAirportSelector) {
            AirportSelectorView(
                store: store,
                onAirportSelected: {
                    isShowingAirportSelector = false
                }
            )
        }
        .sheet(isPresented: $isShowingDeparturePlanner) {
            DeparturePlannerSheet(store: store)
        }
        .task {
            await refreshNow()
        }
        .onReceive(refreshTimer) { _ in
            guard !isShowingAirportSelector else { return }
            Task {
                await refreshNow()
            }
        }
        .onReceive(updatedTicker) { value in
            guard !isShowingAirportSelector else { return }
            now = value
        }
        .onChange(of: store.selectedAirport) { _ in
            guard !isShowingAirportSelector else { return }
            Task {
                await refreshNow()
            }
        }
    }

    private func refreshNow() async {
        await store.refresh()
        now = Date()

        let latestRows = store.displayRowsForSelectedAirport()

        if let selectedRowID,
           latestRows.contains(where: { $0.id == selectedRowID }) {
            self.selectedRowID = selectedRowID
        } else {
            self.selectedRowID = latestRows.first?.id
        }
    }
}

// MARK: - Top Pill

private extension LandingView {

    var airportSelectorPill: some View {
        Button {
            isShowingAirportSelector = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))

                Text("Select Airport")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white.opacity(0.95))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Header

private extension LandingView {

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.selectedAirport.rawValue)
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)

            Text(store.selectedAirport.displayName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
        }
    }
}

// MARK: - Weather + Time

private extension LandingView {

    var weatherRow: some View {
        HStack(spacing: 12) {

            weatherSection
                .frame(maxWidth: .infinity)
                .frame(height: 110)

            timeSection
                .frame(maxWidth: .infinity)
                .frame(height: 110)
        }
    }

    var weatherSection: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text("Weather")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 0)

            HStack(spacing: 10) {

                Image(systemName: weatherSymbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))

                Text(weatherTemperatureLine)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
            }

            Text(weatherConditionLine)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .flowGlassCard()
    }

    var timeSection: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text("Time")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 0)

            HStack(spacing: 10) {

                Image(systemName: "clock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))

                timeClock
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .monospacedDigit()
            }

            Text(timeZoneAbbreviation)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.82))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .flowGlassCard()
    }

    var timeClock: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            Text(timeString(for: context.date))
        }
    }

    func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = store.selectedAirport.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    var timeZoneAbbreviation: String {
        store.selectedAirport.timeZone.abbreviation() ?? ""
    }

    var weatherTemperatureLine: String {
        guard let weather = store.weather else { return "--" }
        return "\(weather.temperatureC)°C"
    }

    var weatherConditionLine: String {
        guard let weather = store.weather else { return "--" }

        let cond = weather.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return cond.isEmpty ? "Clear" : cond
    }

    var weatherSymbolName: String {

        let s = (store.weather?.summary ?? "").lowercased()

        if s.contains("thunder") || s.contains("storm") { return "cloud.bolt.rain.fill" }

        if s.contains("snow") || s.contains("sleet") || s.contains("ice") || s.contains("hail") {
            return "cloud.snow.fill"
        }

        if s.contains("rain") || s.contains("shower") || s.contains("drizzle") {
            return "cloud.rain.fill"
        }

        if s.contains("fog") || s.contains("mist") || s.contains("haze") {
            return "cloud.fog.fill"
        }

        if s.contains("overcast") || s.contains("broken clouds") {
            return "smoke.fill"
        }

        if s.contains("scattered") || s.contains("few clouds") || s.contains("cloud") {
            return "cloud.sun.fill"
        }

        if s.contains("clear") || s.contains("sunny") {
            return "sun.max.fill"
        }

        return "cloud.sun.fill"
    }
}

// MARK: - Security Hero

private extension LandingView {

    var securityHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Security wait")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                refreshButton

                statusBadge
            }

            heroCard

            Text(updatedRelativeText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .flowGlassCard()
    }

    var refreshButton: some View {
        Button {
            Task {
                await store.refresh()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var statusBadge: some View {
        switch confidenceLevel {
        case .live:
            confidenceBadge(
                text: "LIVE",
                textColor: .green,
                dot: AnyView(LivePulseDot())
            )

        case .highConfidence:
            confidenceBadge(
                text: "HIGH CONFIDENCE",
                textColor: Color(hex: "9B6CFF"),
                dot: AnyView(ConfidencePurpleDot())
            )

        case .lowConfidence:
            confidenceBadge(
                text: "LOW CONFIDENCE",
                textColor: .orange,
                dot: AnyView(OrangePulseDot())
            )

        case .comingSoon:
            Text("COMING SOON")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
        }
    }

    func confidenceBadge(text: String, textColor: Color, dot: AnyView) -> some View {
        HStack(spacing: 6) {
            dot

            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.10))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    var heroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            Text(store.selectedAirport.rawValue)
                .font(.system(size: 84, weight: .heavy))
                .foregroundColor(.white.opacity(0.06))

            heroContent
        }
        .frame(height: 175)
    }

    @ViewBuilder
    var heroContent: some View {
        if let row = selectedRow {
            if row.metrics.count > 1 {
                VStack {
                    HStack(spacing: 34) {
                        ForEach(row.metrics) { metric in
                            heroMetric(value: metric.minutes, label: metric.label)
                        }
                    }

                    Spacer()

                    Text(row.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.bottom, 14)
                }
                .padding(.top, 18)
            } else {
                let metric = row.metrics.first

                VStack(spacing: 4) {
                    if row.isClosed {
                        Text("Closed")
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundColor(.red)
                    } else if let minutes = metric?.minutes, minutes == 0 {
                        HStack(spacing: 10) {
                            LivePulseDot()

                            Text("No wait")
                                .font(.system(size: 40, weight: .heavy))
                                .foregroundColor(.green)
                        }
                    } else {
                        Text(metric?.minutes == nil ? "--" : "\(metric!.minutes!)")
                            .font(.system(size: 72, weight: .heavy))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }

                    if usesAverageWaitPresentation {
                        Text("Average wait time")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "9B6CFF").opacity(0.95))
                            .padding(.bottom, 2)
                    }

                    Text(row.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(row.isClosed ? "Closed" : row.subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
            }
        } else {
            VStack(spacing: 6) {
                Text("--")
                    .font(.system(size: 72, weight: .heavy))
                    .foregroundColor(.white)
                    .monospacedDigit()

                if usesAverageWaitPresentation {
                    Text("Average wait time")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "9B6CFF").opacity(0.95))
                }

                Text("No data")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
    }

    @ViewBuilder
    func heroMetric(value: Int?, label: String) -> some View {
        VStack(spacing: 6) {
            if let minutes = value, minutes == 0 {
                HStack(spacing: 6) {
                    LivePulseDot()

                    Text("No wait")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                }
            } else {
                Text(value == nil ? "--" : "\(value!)")
                    .font(.system(size: 58, weight: .heavy))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
        }
    }

    var updatedRelativeText: String {
        guard let date = store.lastUpdated else {
            switch confidenceLevel {
            case .live:
                return "Live feed · Waiting for first update"
            case .highConfidence:
                return "High confidence feed · Waiting for first check"
            case .lowConfidence:
                return "Estimated feed · Waiting for refresh"
            case .comingSoon:
                return "Coming soon"
            }
        }

        let seconds = max(0, Int(now.timeIntervalSince(date)))
        let relative = relativeAgeString(for: seconds)

        switch confidenceLevel {
        case .live:
            if seconds >= 900 {
                return "Live feed · Delayed · Last update \(relative)"
            } else {
                return "Live feed · Updated \(relative)"
            }

        case .highConfidence:
            if seconds >= 900 {
                return "High confidence feed · Last checked \(relative)"
            } else {
                return "High confidence feed · Checked \(relative)"
            }

        case .lowConfidence:
            if seconds >= 900 {
                return "Estimated feed · Last refresh \(relative)"
            } else {
                return "Estimated feed · Refreshed \(relative)"
            }

        case .comingSoon:
            return "Coming soon"
        }
    }

    func relativeAgeString(for seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s ago"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m ago"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h ago"
        }

        let days = hours / 24
        return "\(days)d ago"
    }
}

// MARK: - Departure Planner

private extension LandingView {

    var departurePlannerButton: some View {
        Button {
            isShowingDeparturePlanner = true
        } label: {
            HStack(spacing: 12) {

                Image(systemName: "car.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan my departure")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Travel time + security wait")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.58))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Error

private extension LandingView {

    @ViewBuilder
    var errorSection: some View {
        if let error = store.errorText, !error.isEmpty {
            Text(error)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 6)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Flow Brand

private enum FlowBrand {
    static let backgroundTop = Color(hex: "2A0C5A")
    static let backgroundMid = Color(hex: "3B136E")
    static let backgroundBottom = Color(hex: "14062F")

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                backgroundTop,
                backgroundMid,
                backgroundBottom
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private enum FlowConfidenceLevel {
    case live
    case highConfidence
    case lowConfidence
    case comingSoon
}

// MARK: - Purple Confidence Dot

private struct ConfidencePurpleDot: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "9B6CFF").opacity(0.22))
                .frame(width: 16, height: 16)
                .scaleEffect(animate ? 1.35 : 0.85)
                .opacity(animate ? 0.20 : 0.65)

            Circle()
                .fill(Color(hex: "9B6CFF"))
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

// MARK: - Orange Pulse Dot

private struct OrangePulseDot: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.22))
                .frame(width: 16, height: 16)
                .scaleEffect(animate ? 1.35 : 0.85)
                .opacity(animate ? 0.20 : 0.65)

            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

// MARK: - Glass Card

extension View {
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
