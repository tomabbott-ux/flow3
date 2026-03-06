import SwiftUI

struct LandingView: View {

    @ObservedObject var store: LandingStore
    @State private var selectedRowID: String? = nil

    private var displayRows: [AirportDisplayRow] {
        store.displayRowsForSelectedAirport()
    }

    private var selectedRow: AirportDisplayRow? {
        if let selectedRowID {
            return displayRows.first(where: { $0.id == selectedRowID }) ?? displayRows.first
        }
        return displayRows.first
    }

    private var isLiveAirport: Bool {
        AirportRegistry.definition(for: store.selectedAirport)?.isLive ?? false
    }

    var body: some View {
        ZStack {
            FlowBrand.backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    weatherRow
                    securityHero

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
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refresh()
            selectedRowID = store.displayRowsForSelectedAirport().first?.id
            store.startAutoRefresh()
        }
        .onChange(of: store.selectedAirport) { _ in
            selectedRowID = store.displayRowsForSelectedAirport().first?.id
        }
        .onDisappear {
            store.stopAutoRefresh()
        }
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

            Text(store.selectedAirport.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.75))

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Image(systemName: weatherSymbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))

                Text(weatherLine)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .flowGlassCard()
    }

    var timeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Time")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text(store.selectedAirport.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.75))

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

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    var weatherLine: String {
        guard let weather = store.weather else { return "--" }
        let temp = "\(weather.temperatureC)°C"
        let cond = weather.summary.trimmingCharacters(in: .whitespacesAndNewlines)
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

// MARK: - Security Hero

private extension LandingView {

    var securityHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Security wait")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if isLiveAirport {
                    HStack(spacing: 6) {
                        LivePulseDot()

                        Text("LIVE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
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
                } else {
                    Text("EST")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
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

            heroCard

            Text("Updated: \(updatedText)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .flowGlassCard()
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

                VStack(spacing: 6) {
                    Text(metric?.minutes == nil ? "--" : "\(metric!.minutes!)")
                        .font(.system(size: 72, weight: .heavy))
                        .foregroundColor(.white)
                        .monospacedDigit()

                    Text(row.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(row.subtitle)
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

                Text("No data")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
    }

    func heroMetric(value: Int?, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value == nil ? "--" : "\(value!)")
                .font(.system(size: 58, weight: .heavy))
                .foregroundColor(.white)
                .monospacedDigit()

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
        }
    }

    var updatedText: String {
        guard let date = store.lastUpdated else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        return formatter.string(from: date)
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
