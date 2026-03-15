import Foundation
import Combine

@MainActor
final class LandingStore: ObservableObject {

    // MARK: - Published state

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

    // MARK: - Tracked Flight

    @Published var trackedFlight: TrackedFlight?

    // MARK: - Services

    private let waitTimeService: WaitTimeService
    private let weatherService: WeatherService

    private let travelTimeService = TravelTimeService()
    private let flightLookupService = FlightLookupService()

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

    // MARK: - Init

    init(
        waitTimeService: WaitTimeService,
        weatherService: WeatherService
    ) {
        self.waitTimeService = waitTimeService
        self.weatherService = weatherService

        self.trackedFlight = SavedFlightStore.shared.load()
    }

    deinit {
        autoRefreshTask?.cancel()
        prefetchTask?.cancel()
    }

    // MARK: - Refresh

    func refresh() async {
        let airport = selectedAirport
        await refreshAirport(airport, updateVisibleState: true)

        if trackedFlight != nil {
            await refreshTrackedFlight()
        }

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
        }
    }

    // MARK: - Wait times

    private func loadWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        if let cached = waitTimeCache[airport],
           let refreshedAt = refreshedAtCache[airport],
           Date().timeIntervalSince(refreshedAt) <= waitTimeCacheTTL {
            return cached
        }

        return try await waitTimeService.fetchWaitTimes(for: airport)
    }

    // MARK: - Weather

    private func loadWeather(for airport: FlowAirport) async throws -> WeatherSnapshot {

        if let cached = weatherCache[airport] {
            let age = Date().timeIntervalSince(cached.observedAt)

            if age <= weatherCacheTTL {
                return cached
            }
        }

        return try await weatherService.fetchWeather(for: airport)
    }

    // MARK: - Selected Airport

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

        while results.count < limit &&
              (currentIndex - offset >= 0 || currentIndex + offset < all.count) {

            if currentIndex + offset < all.count {
                results.append(all[currentIndex + offset])
            }

            if results.count >= limit { break }

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

    // MARK: - Auto Refresh

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

    // MARK: - Helpers

    func overallMinutes(_ queue: QueueType) -> Int? {

        let relevant = waitTimes
            .filter { $0.airport == selectedAirport && $0.queueType == queue }
            .map { $0.minutes }

        return relevant.min()
    }

    func allWaitTimes() -> [WaitTimeEstimate] {
        waitTimes
    }

    // MARK: - Tracked Flight

    func trackFlight(_ flight: TrackedFlight) {

        trackedFlight = flight
        SavedFlightStore.shared.save(flight)

        Task {
            await FlowNotificationManager.shared.requestPermission()
            FlowNotificationManager.shared.scheduleTrackedFlightReminders(for: flight)
        }
    }

    func clearTrackedFlight() {

        trackedFlight = nil

        SavedFlightStore.shared.clear()

        FlowNotificationManager.shared.clearTrackedFlightNotifications()
    }

    func refreshTrackedFlight() async {

        guard let current = trackedFlight else { return }
        guard selectedAirport == .lhr else { return }

        do {

            let refreshedFlight = try await flightLookupService.lookupFlight(
                flightNumber: current.flightNumber,
                date: current.departureTime
            )

            let travelMinutes = try await travelTimeService.drivingMinutesToHeathrow()
            let securityMinutes = max(0, overallMinutes(.general) ?? 0)

            let plan = DeparturePlanner.makePlan(
                departureTime: refreshedFlight.departureTime,
                travelMinutes: travelMinutes,
                securityMinutes: securityMinutes,
                checkedBags: current.bagBufferMinutes > 0
            )

            let trend: LeaveTimeTrend

            if plan.recommendedLeaveTime < current.leaveTime {
                trend = .earlier
            } else if plan.recommendedLeaveTime > current.leaveTime {
                trend = .later
            } else {
                trend = .unchanged
            }

            let updated = TrackedFlight(
                flightNumber: refreshedFlight.flightNumber,
                route: "\(refreshedFlight.originIATA) → \(refreshedFlight.destinationIATA)",
                airline: refreshedFlight.airline,
                terminal: refreshedFlight.terminal ?? "",
                departureTime: refreshedFlight.departureTime,
                leaveTime: plan.recommendedLeaveTime,
                gateTargetTime: plan.gateTargetTime,
                travelMinutes: plan.travelMinutes,
                securityMinutes: plan.securityMinutes,
                airportBufferMinutes: plan.airportBufferMinutes,
                bagBufferMinutes: plan.bagBufferMinutes,
                leaveTimeTrend: trend
            )

            let oldLeaveTime = current.leaveTime

            trackedFlight = updated
            SavedFlightStore.shared.save(updated)

            await FlowNotificationManager.shared.requestPermission()

            FlowNotificationManager.shared.scheduleTrackedFlightReminders(for: updated)

            if oldLeaveTime != updated.leaveTime {

                FlowNotificationManager.shared.notifyLeaveTimeChanged(
                    flight: updated,
                    oldLeaveTime: oldLeaveTime,
                    newLeaveTime: updated.leaveTime
                )
            }

        } catch {

            print("Tracked flight refresh failed: \(error.localizedDescription)")
        }
    }
}
