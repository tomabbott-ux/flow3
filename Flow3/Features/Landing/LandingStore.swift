import Foundation
import Combine

@MainActor
final class LandingStore: ObservableObject {

    // MARK: - Published state (used by LandingView)

    @Published var selectedAirport: FlowAirport = .atl
    @Published var weather: WeatherSnapshot?
    @Published var lastUpdated: Date?
    @Published var errorText: String?

    // ✅ This is the missing piece your extensions expect
    @Published private(set) var waitTimes: [WaitTimeEstimate] = []

    // MARK: - Services

    private let waitTimeService: WaitTimeService
    private let weatherService: WeatherService

    // MARK: - Auto refresh

    private var autoRefreshTask: Task<Void, Never>?
    private var autoRefreshInterval: TimeInterval = 60

    init(
        waitTimeService: WaitTimeService,
        weatherService: WeatherService
    ) {
        self.waitTimeService = waitTimeService
        self.weatherService = weatherService
    }

    deinit {
        // ✅ deinit is NOT actor-isolated — do not call MainActor methods directly
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    // MARK: - Refresh

    func refresh() async {
        do {
            errorText = nil

            async let wt = waitTimeService.fetchWaitTimes(for: selectedAirport)
            async let wx = weatherService.fetchWeather(for: selectedAirport)

            let (newWaitTimes, newWeather) = try await (wt, wx)

            self.waitTimes = newWaitTimes
            self.weather = newWeather
            self.lastUpdated = Date()

        } catch {
            self.errorText = "Refresh failed: \(error.localizedDescription)"
            // Keep last good data on screen if refresh fails.
        }
    }

    // MARK: - Auto refresh (60s)

    /// Starts auto-refresh. Safe to call multiple times (it restarts).
    func startAutoRefresh(every seconds: TimeInterval = 60) {
        autoRefreshInterval = seconds
        stopAutoRefresh() // restart cleanly

        autoRefreshTask = Task { [weak self] in
            guard let self else { return }

            // Small delay so first .task refresh can run without fighting
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

    /// Overall minutes for the currently selected airport (fallback logic).
    func overallMinutes(_ queue: QueueType) -> Int? {
        let relevant = waitTimes
            .filter { $0.airport == selectedAirport && $0.queueType == queue }
            .map { $0.minutes }

        return relevant.min()
    }

    /// Allows your other airport extensions (ATL/JFK/LHR) to read raw waitTimes if needed.
    func allWaitTimes() -> [WaitTimeEstimate] {
        waitTimes
    }
}
