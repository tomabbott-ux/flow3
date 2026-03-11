import Foundation
import Combine

@MainActor
final class LandingStore: ObservableObject {

    // MARK: - Published state (used by LandingView)

    @Published var selectedAirport: FlowAirport = .atl {
        didSet {
            guard oldValue != selectedAirport else { return }

            Task { [weak self] in
                await self?.handleSelectedAirportChanged()
            }
        }
    }

    @Published var weather: WeatherSnapshot?
    @Published var lastUpdated: Date?
    @Published var errorText: String?

    @Published private(set) var waitTimes: [WaitTimeEstimate] = []

    // MARK: - Services

    private let waitTimeService: WaitTimeService
    private let weatherService: WeatherService

    // MARK: - Auto refresh

    private var autoRefreshTask: Task<Void, Never>?
    private var autoRefreshInterval: TimeInterval = 60

    // MARK: - Cache

    private var waitTimeCache: [FlowAirport: [WaitTimeEstimate]] = [:]
    private var weatherCache: [FlowAirport: WeatherSnapshot] = [:]
    private var refreshedAtCache: [FlowAirport: Date] = [:]

    private let waitTimeCacheTTL: TimeInterval = 45
    private let weatherCacheTTL: TimeInterval = 600

    // MARK: - Prefetch

    private var prefetchTask: Task<Void, Never>?

    init(
        waitTimeService: WaitTimeService,
        weatherService: WeatherService
    ) {
        self.waitTimeService = waitTimeService
        self.weatherService = weatherService
    }

    deinit {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil

        prefetchTask?.cancel()
        prefetchTask = nil
    }

    // MARK: - Refresh

    func refresh() async {
        let airport = selectedAirport
        await refreshAirport(airport, updateVisibleState: true)
        startPrefetchAroundSelectedAirport()
    }

    private func refreshAirport(_ airport: FlowAirport, updateVisibleState: Bool) async {
        do {
            if updateVisibleState {
                errorText = nil
            }

            async let wt = loadWaitTimes(for: airport)
            async let wx = loadWeather(for: airport)

            let (newWaitTimes, newWeather) = try await (wt, wx)
            let refreshedAt = Date()

            waitTimeCache[airport] = newWaitTimes
            weatherCache[airport] = newWeather
            refreshedAtCache[airport] = refreshedAt

            if updateVisibleState, airport == selectedAirport {
                waitTimes = newWaitTimes
                weather = newWeather
                lastUpdated = refreshedAt
            }

        } catch {
            if updateVisibleState, airport == selectedAirport {
                errorText = "Refresh failed: \(error.localizedDescription)"
            }
            // Keep last good data on screen if refresh fails.
        }
    }

    private func loadWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        if let cached = waitTimeCache[airport],
           let refreshedAt = refreshedAtCache[airport],
           Date().timeIntervalSince(refreshedAt) <= waitTimeCacheTTL {
            return cached
        }

        return try await waitTimeService.fetchWaitTimes(for: airport)
    }

    private func loadWeather(for airport: FlowAirport) async throws -> WeatherSnapshot {
        if let cached = weatherCache[airport] {
            let age = Date().timeIntervalSince(cached.observedAt)
            if age <= weatherCacheTTL {
                return cached
            }
        }

        return try await weatherService.fetchWeather(for: airport)
    }

    // MARK: - Selected airport handling

    private func handleSelectedAirportChanged() async {
        applyCachedSnapshotIfAvailable(for: selectedAirport)
        startPrefetchAroundSelectedAirport()
    }

    private func applyCachedSnapshotIfAvailable(for airport: FlowAirport) {
        if let cachedWaitTimes = waitTimeCache[airport] {
            waitTimes = cachedWaitTimes
        }

        if let cachedWeather = weatherCache[airport] {
            weather = cachedWeather
        }

        if let refreshedAt = refreshedAtCache[airport] {
            lastUpdated = refreshedAt
        }
    }

    // MARK: - Prefetch

    private func startPrefetchAroundSelectedAirport() {
        prefetchTask?.cancel()

        let airportsToPrefetch = neighboringAirports(around: selectedAirport, limit: 3)

        prefetchTask = Task { [weak self] in
            guard let self else { return }

            for airport in airportsToPrefetch {
                if Task.isCancelled { return }

                let shouldRefreshWaitTimes = shouldRefreshWaitTimeCache(for: airport)
                let shouldRefreshWeather = shouldRefreshWeatherCache(for: airport)

                if !shouldRefreshWaitTimes && !shouldRefreshWeather {
                    continue
                }

                await self.refreshAirport(airport, updateVisibleState: false)

                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func neighboringAirports(around airport: FlowAirport, limit: Int) -> [FlowAirport] {
        let all = AirportRegistry.airports.map(\.airport)

        guard let currentIndex = all.firstIndex(of: airport) else {
            return Array(all.prefix(limit))
        }

        var results: [FlowAirport] = []
        var offset = 1

        while results.count < limit && (currentIndex - offset >= 0 || currentIndex + offset < all.count) {
            if currentIndex + offset < all.count {
                results.append(all[currentIndex + offset])
            }

            if results.count >= limit {
                break
            }

            if currentIndex - offset >= 0 {
                results.append(all[currentIndex - offset])
            }

            offset += 1
        }

        return Array(results.prefix(limit))
    }

    private func shouldRefreshWaitTimeCache(for airport: FlowAirport) -> Bool {
        guard let refreshedAt = refreshedAtCache[airport],
              waitTimeCache[airport] != nil else {
            return true
        }

        return Date().timeIntervalSince(refreshedAt) > waitTimeCacheTTL
    }

    private func shouldRefreshWeatherCache(for airport: FlowAirport) -> Bool {
        guard let cachedWeather = weatherCache[airport] else {
            return true
        }

        return Date().timeIntervalSince(cachedWeather.observedAt) > weatherCacheTTL
    }

    // MARK: - Auto refresh (60s)

    /// Starts auto-refresh. Safe to call multiple times (it restarts).
    func startAutoRefresh(every seconds: TimeInterval = 60) {
        autoRefreshInterval = seconds
        stopAutoRefresh()

        autoRefreshTask = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: 300_000_000)

            while !Task.isCancelled {
                await self.refresh()
                let ns = UInt64(self.autoRefreshInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    // MARK: - Shared helpers used by views/extensions

    func overallMinutes(_ queue: QueueType) -> Int? {
        let relevant = waitTimes
            .filter { $0.airport == selectedAirport && $0.queueType == queue }
            .map { $0.minutes }

        return relevant.min()
    }

    func allWaitTimes() -> [WaitTimeEstimate] {
        waitTimes
    }
}
