import Foundation
import Combine

@MainActor
final class LandingStore: ObservableObject {

    private enum PreferenceKeys {
        static let defaultAirportCode = "flow_default_airport"
        static let lastSelectedAirportCode = "lastSelectedAirportCode"
    }

    // MARK: - Published state

    @Published var selectedAirport: FlowAirport = .atl {
        didSet {
            guard oldValue != selectedAirport else { return }

            UserDefaults.standard.set(
                selectedAirport.rawValue,
                forKey: PreferenceKeys.lastSelectedAirportCode
            )

            Task { [weak self] in
                await self?.handleSelectedAirportChanged()
            }
        }
    }

    @Published var weather: WeatherSnapshot?
    @Published var lastUpdated: Date?
    @Published var errorText: String?
    @Published private(set) var waitTimes: [WaitTimeEstimate] = []
    @Published private(set) var alerts: [FlowAlert] = []

    // MARK: - Calendar Review Target

    @Published var reviewCalendarFlight: PendingCalendarFlight?

    // MARK: - Calendar Flights

    @Published var pendingCalendarFlights: [PendingCalendarFlight] = [] {
        didSet {
            rebuildAlerts()

            if let reviewCalendarFlight,
               !pendingCalendarFlights.contains(where: { $0.id == reviewCalendarFlight.id }) {
                self.reviewCalendarFlight = nil
            }
        }
    }

    // Legacy selection support
    @Published var selectedPendingCalendarFlightID: String?

    var pendingCalendarFlight: PendingCalendarFlight? {
        reviewCalendarFlight
    }

    func dismissPendingCalendarFlight() {
        reviewCalendarFlight = nil
        selectedPendingCalendarFlightID = nil
    }

    func setPendingCalendarFlights(_ flights: [PendingCalendarFlight]) {
        pendingCalendarFlights = flights.sorted { $0.departureDate < $1.departureDate }
    }

    func addPendingCalendarFlight(_ flight: PendingCalendarFlight) {
        guard !pendingCalendarFlights.contains(where: { $0.id == flight.id }) else { return }
        pendingCalendarFlights.append(flight)
        pendingCalendarFlights.sort { $0.departureDate < $1.departureDate }
    }

    // MARK: - Tracked Flight

    @Published var trackedFlight: TrackedFlight?

    func setTrackedFlight(_ flight: TrackedFlight) {
        trackedFlight = flight

        if let matchedPending = pendingCalendarFlights.first(where: {
            $0.flightNumber.caseInsensitiveCompare(flight.flightNumber) == .orderedSame
        }) {
            pendingCalendarFlights.removeAll { $0.id == matchedPending.id }

            if selectedPendingCalendarFlightID == matchedPending.id {
                selectedPendingCalendarFlightID = nil
            }

            if reviewCalendarFlight?.id == matchedPending.id {
                reviewCalendarFlight = nil
            }
        }

        if let departureAirport = trackedDepartureAirport(from: flight.route) {
            selectedAirport = departureAirport
        }

        SavedFlightStore.shared.save(flight)
        FlowWatchConnectivityManager.shared.syncTrackedFlight(flight)
        rebuildAlerts()

        Task {
            await FlowNotificationManager.shared.requestPermission()
            FlowNotificationManager.shared.scheduleTrackedFlightReminders(for: flight)
            await FlowLiveActivityManager.shared.start(for: flight)
        }
    }

    func trackFlight(_ flight: TrackedFlight) {
        setTrackedFlight(flight)
    }

    func clearTrackedFlight() {
        trackedFlight = nil
        SavedFlightStore.shared.clear()
        FlowWatchConnectivityManager.shared.syncTrackedFlight(nil)
        FlowNotificationManager.shared.clearTrackedFlightNotifications()
        rebuildAlerts()

        Task {
            await FlowLiveActivityManager.shared.end()
        }
    }

    // MARK: - Services

    private let waitTimeService: WaitTimeService
    private let weatherService: WeatherService

    private let travelTimeService = TravelTimeService()
    private let flightLookupService = LiveFlightService()

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

        if let defaultAirportCode = UserDefaults.standard.string(forKey: PreferenceKeys.defaultAirportCode),
           let airport = AirportRegistry.airports
            .map(\.airport)
            .first(where: { $0.rawValue == defaultAirportCode }) {
            self.selectedAirport = airport
        } else if let lastAirportCode = UserDefaults.standard.string(forKey: PreferenceKeys.lastSelectedAirportCode),
                  let airport = AirportRegistry.airports
            .map(\.airport)
            .first(where: { $0.rawValue == lastAirportCode }) {
            self.selectedAirport = airport
        } else {
            self.selectedAirport = .atl
        }

        rebuildAlerts()
    }

    deinit {
        autoRefreshTask?.cancel()
        prefetchTask?.cancel()
    }

    // MARK: - Refresh

    func refresh(
        prefetchNeighbors: Bool = true,
        shouldRefreshTrackedFlight: Bool = true
    ) async {
        let airport = selectedAirport
        await refreshAirport(airport, updateVisibleState: true)

        if shouldRefreshTrackedFlight, trackedFlight != nil {
            await refreshTrackedFlight()
        }

        if prefetchNeighbors {
            startPrefetchAroundSelectedAirport(delay: 0.75)
        }

        rebuildAlerts()
    }

    private func refreshAirport(_ airport: FlowAirport, updateVisibleState: Bool) async {
        if updateVisibleState {
            errorText = nil
        }

        async let waitTimesResult = loadWaitTimesResult(for: airport)
        async let weatherResult = loadWeatherResult(for: airport)

        let (waitResult, wxResult) = await (waitTimesResult, weatherResult)
        let refreshedAt = Date()

        var didUpdateAnything = false
        var waitTimesError: Error?
        var weatherError: Error?

        switch waitResult {
        case .success(let newWaitTimes):
            waitTimeCache[airport] = newWaitTimes
            refreshedAtCache[airport] = refreshedAt
            didUpdateAnything = true

            if updateVisibleState, airport == selectedAirport {
                waitTimes = newWaitTimes
                lastUpdated = refreshedAt
            }

        case .failure(let error):
            waitTimesError = error
        }

        switch wxResult {
        case .success(let newWeather):
            weatherCache[airport] = newWeather
            refreshedAtCache[airport] = refreshedAt
            didUpdateAnything = true

            if updateVisibleState, airport == selectedAirport {
                weather = newWeather
                lastUpdated = refreshedAt
            }

        case .failure(let error):
            weatherError = error
        }

        if updateVisibleState, airport == selectedAirport {
            if didUpdateAnything {
                errorText = nil
            } else if airport == .atl {
                errorText = nil
            } else if let waitTimesError {
                errorText = "Refresh failed: \(waitTimesError.localizedDescription)"
            } else if let weatherError {
                errorText = "Refresh failed: \(weatherError.localizedDescription)"
            }

            rebuildAlerts()
        }
    }

    private func loadWaitTimesResult(for airport: FlowAirport) async -> Result<[WaitTimeEstimate], Error> {
        do {
            let result = try await loadWaitTimes(for: airport)
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    private func loadWeatherResult(for airport: FlowAirport) async -> Result<WeatherSnapshot, Error> {
        do {
            let result = try await loadWeather(for: airport)
            return .success(result)
        } catch {
            return .failure(error)
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
        rebuildAlerts()
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

    private func startPrefetchAroundSelectedAirport(delay: TimeInterval = 0) {
        prefetchTask?.cancel()

        let airportsToPrefetch = neighboringAirports(around: selectedAirport, limit: 3)

        prefetchTask = Task { [weak self] in
            guard let self else { return }

            if delay > 0 {
                let delayNs = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delayNs)
            }

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

    private func isFlightFinishedStatus(_ status: String?) -> Bool {
        guard let status else { return false }

        let normalized = status
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return normalized == "departed" || normalized == "arrived"
    }

    private func trackedDepartureAirportCode(from route: String) -> String {
        route
            .components(separatedBy: "→")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? selectedAirport.rawValue
    }

    private func trackedDepartureAirport(from route: String) -> FlowAirport? {
        let code = route
            .components(separatedBy: "→")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard let code else { return nil }

        return AirportRegistry.airports
            .map(\.airport)
            .first(where: { $0.rawValue.uppercased() == code })
    }

    private func flowAirport(from code: String) -> FlowAirport? {
        AirportRegistry.airports
            .map(\.airport)
            .first(where: { $0.rawValue.uppercased() == code.uppercased() })
    }

    private func preferredText(_ newer: String?, fallback: String?) -> String? {
        let newValue = newer?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let newValue, !newValue.isEmpty, newValue != "—" {
            return newValue
        }

        let fallbackValue = fallback?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fallbackValue, !fallbackValue.isEmpty, fallbackValue != "—" {
            return fallbackValue
        }

        return nil
    }

    // MARK: - Refresh tracked flight

    func refreshTrackedFlight() async {
        guard let current = trackedFlight else { return }

        do {
            let refreshedFlight = try await flightLookupService.lookupFlight(
                flightNumber: current.flightNumber,
                date: current.departureTime,
                airportIATA: selectedAirport.rawValue
            )

            print("Tracked refresh lookup airport:", selectedAirport.rawValue)
            print("Tracked refresh terminal from service:", refreshedFlight.terminal ?? "nil")
            print("Tracked refresh gate from service:", refreshedFlight.gate ?? "nil")
            print("Tracked refresh status from service:", refreshedFlight.status ?? "nil")

            if isFlightFinishedStatus(refreshedFlight.status) {
                await FlowNotificationManager.shared.requestPermission()
                FlowNotificationManager.shared.notifyFlightDeparted(current)
                clearTrackedFlight()
                return
            }

            let travelMinutes: Int
            do {
                travelMinutes = try await travelTimeService.drivingMinutes(to: selectedAirport)
            } catch {
                print("Travel time fallback used:", error.localizedDescription)
                travelMinutes = current.travelMinutes
            }

            let preferredRouteID: String? = current.securityRouteMode == .manual
                ? current.securityRouteID
                : nil

            let securitySelection = plannerSecuritySelection(
                for: selectedAirport,
                flightTerminal: refreshedFlight.terminal,
                preferredRouteID: preferredRouteID
            )

            let routeClosed =
                current.securityRouteMode == .manual &&
                preferredRouteID != nil &&
                securitySelection.option.id != preferredRouteID

            let securityMinutes: Int
            let securityRouteMode: SecurityRouteMode
            let securityRouteID: String?
            let securityRouteTitle: String
            let securityRouteSubtitle: String
            let securityRouteDetail: String
            let securityRouteIsPreCheckOnly: Bool

            if routeClosed {
                securityMinutes = current.securityMinutes
                securityRouteMode = current.securityRouteMode
                securityRouteID = current.securityRouteID
                securityRouteTitle = current.securityRouteTitle
                securityRouteSubtitle = current.securityRouteSubtitle
                securityRouteDetail = current.securityRouteDetail
                securityRouteIsPreCheckOnly = current.securityRouteIsPreCheckOnly
            } else {
                securityMinutes = max(0, securitySelection.option.minutes)
                securityRouteMode = securitySelection.mode
                securityRouteID = securitySelection.mode == .manual
                    ? securitySelection.option.id
                    : nil
                securityRouteTitle = securitySelection.option.title
                securityRouteSubtitle = securitySelection.option.subtitle
                securityRouteDetail = securitySelection.mode == .manual
                    ? "\(securitySelection.option.detail) · Chosen by you"
                    : securitySelection.option.detail
                securityRouteIsPreCheckOnly = securitySelection.option.isPreCheckOnly
            }

            let plan = DeparturePlanner.makePlan(
                departureTime: refreshedFlight.departureTime,
                travelMinutes: travelMinutes,
                securityMinutes: securityMinutes,
                checkedBags: current.bagBufferMinutes > 0
            )

            let deltaMinutes = Int(
                plan.recommendedLeaveTime.timeIntervalSince(current.leaveTime) / 60
            )

            let trend: LeaveTimeTrend
            if deltaMinutes <= -5 {
                trend = .earlier
            } else if deltaMinutes >= 5 {
                trend = .later
            } else {
                trend = .unchanged
            }

            let updatedTerminal = {
                let trimmed = (refreshedFlight.terminal ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? current.terminal : trimmed
            }()

            let updatedGate: String? = {
                let trimmed = (refreshedFlight.gate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? current.gate : trimmed
            }()

            let updatedStatus: String? = {
                let trimmed = (refreshedFlight.status ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? current.status : trimmed
            }()

            print("Tracked refresh merged terminal:", updatedTerminal)
            print("Tracked refresh merged gate:", updatedGate ?? "nil")

            let updated = TrackedFlight(
                flightNumber: refreshedFlight.flightNumber,
                route: "\(refreshedFlight.originIATA) → \(refreshedFlight.destinationIATA)",
                airline: refreshedFlight.airline,
                terminal: updatedTerminal,
                gate: updatedGate,
                status: updatedStatus,
                departureTime: refreshedFlight.departureTime,
                leaveTime: plan.recommendedLeaveTime,
                gateTargetTime: plan.gateTargetTime,
                travelMinutes: plan.travelMinutes,
                securityMinutes: securityMinutes,
                airportBufferMinutes: plan.airportBufferMinutes,
                bagBufferMinutes: plan.bagBufferMinutes,
                leaveTimeTrend: trend,
                securityRouteMode: securityRouteMode,
                securityRouteID: securityRouteID,
                securityRouteTitle: securityRouteTitle,
                securityRouteSubtitle: securityRouteSubtitle,
                securityRouteDetail: securityRouteDetail,
                securityRouteIsPreCheckOnly: securityRouteIsPreCheckOnly
            )

            let oldFlight = current
            trackedFlight = updated

            SavedFlightStore.shared.save(updated)
            FlowWatchConnectivityManager.shared.syncTrackedFlight(updated)

            await FlowNotificationManager.shared.requestPermission()

            FlowNotificationManager.shared.scheduleTrackedFlightReminders(for: updated)
            FlowNotificationManager.shared.notifyTrackedFlightChanged(
                oldFlight: oldFlight,
                newFlight: updated
            )
            FlowNotificationManager.shared.notifyDepartureTimeChanged(
                oldFlight: oldFlight,
                newFlight: updated
            )

            if routeClosed {
                FlowNotificationManager.shared.notifyCheckpointClosed(updated)
            }

            await FlowLiveActivityManager.shared.update(for: updated)

        } catch {
            print("Tracked flight refresh failed:", error.localizedDescription)
        }
    }

    // MARK: - Alerts

    func rebuildAlerts() {
        var items: [FlowAlert] = []

        for pending in pendingCalendarFlights.sorted(by: { $0.departureDate < $1.departureDate }) {
            items.append(
                FlowAlert(
                    kind: .calendarFlightDetected,
                    severity: .info,
                    title: "Upcoming flight found",
                    message: "We found \(pending.flightNumber) in your calendar. Tap to review it in Search.",
                    airportCode: pending.departureAirportCode ?? selectedAirport.rawValue,
                    relatedFlightID: pending.id
                )
            )
        }

        if let flight = trackedFlight {
            let secondsUntilLeave = flight.leaveTime.timeIntervalSinceNow

            if secondsUntilLeave <= 0 {
                items.append(
                    FlowAlert(
                        kind: .leaveNow,
                        severity: .critical,
                        title: "Leave now",
                        message: "Your recommended leave time for \(flight.flightNumber) is now. Head to the airport.",
                        airportCode: trackedDepartureAirportCode(from: flight.route)
                    )
                )
            } else if secondsUntilLeave <= 30 * 60 {
                items.append(
                    FlowAlert(
                        kind: .leaveSoon,
                        severity: .warning,
                        title: "Leave soon",
                        message: "It’s nearly time to leave for \(flight.flightNumber).",
                        airportCode: trackedDepartureAirportCode(from: flight.route)
                    )
                )
            } else {
                items.append(
                    FlowAlert(
                        kind: .onTrack,
                        severity: .info,
                        title: "You’re on track",
                        message: "\(flight.flightNumber) is being tracked and your current leave plan still looks good.",
                        airportCode: trackedDepartureAirportCode(from: flight.route)
                    )
                )
            }

            items.append(
                FlowAlert(
                    kind: .trackedFlight,
                    severity: .info,
                    title: "Flight tracking on",
                    message: "Tracking \(flight.flightNumber) from \(flight.route.replacingOccurrences(of: "→", with: "to")).",
                    airportCode: trackedDepartureAirportCode(from: flight.route)
                )
            )
        }

        if waitTimes.contains(where: { $0.sourceType == .estimated && $0.airport == selectedAirport }) {
            items.append(
                FlowAlert(
                    kind: .securityRising,
                    severity: .info,
                    title: "Using estimated airport data",
                    message: "Flow is currently showing estimated waits for \(selectedAirport.rawValue), not a live feed.",
                    airportCode: selectedAirport.rawValue
                )
            )
        }

        if let generalMinutes = overallMinutes(.general), generalMinutes >= 45 {
            items.append(
                FlowAlert(
                    kind: .securityHigh,
                    severity: .warning,
                    title: "Security is busy",
                    message: "\(selectedAirport.rawValue) security is currently around \(generalMinutes) minutes.",
                    airportCode: selectedAirport.rawValue
                )
            )
        }

        alerts = items.sorted { lhs, rhs in
            let lhsScore = severityRank(lhs.severity) * 10 + kindRank(lhs.kind)
            let rhsScore = severityRank(rhs.severity) * 10 + kindRank(rhs.kind)
            return lhsScore < rhsScore
        }
    }

    private func severityRank(_ severity: FlowAlertSeverity) -> Int {
        switch severity {
        case .critical:
            return 0
        case .warning:
            return 1
        case .info:
            return 2
        }
    }

    private func kindRank(_ kind: FlowAlertKind) -> Int {
        switch kind {
        case .leaveNow:
            return 0
        case .leaveSoon:
            return 1
        case .calendarFlightDetected:
            return 2
        case .securityHigh:
            return 3
        case .securityRising:
            return 4
        case .checkpointClosed:
            return 5
        case .weatherImpact:
            return 6
        case .trackedFlight:
            return 7
        case .onTrack:
            return 8
        }
    }
}
