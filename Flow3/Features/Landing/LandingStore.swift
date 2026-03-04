import Foundation
import Combine

@MainActor
final class LandingStore: ObservableObject {

    struct TerminalMinutes: Hashable {
        let terminal: Int
        let general: Int?
        let precheck: Int?
    }

    @Published var selectedAirport: FlowAirport = .atl
    @Published var waitTimes: [WaitTimeEstimate] = []
    @Published var weather: WeatherSnapshot? = nil
    @Published var lastUpdated: Date? = nil
    @Published var errorText: String? = nil

    private let waitTimeService: WaitTimeService
    private let weatherService: WeatherService

    private var autoRefreshTask: Task<Void, Never>? = nil

    init(waitTimeService: WaitTimeService, weatherService: WeatherService) {
        self.waitTimeService = waitTimeService
        self.weatherService = weatherService
    }

    func refresh() async {
        errorText = nil
        do {
            async let wt = waitTimeService.fetchWaitTimes(for: selectedAirport)
            async let wx = weatherService.fetchWeather(for: selectedAirport)

            let (wait, w) = try await (wt, wx)
            self.waitTimes = wait
            self.weather = w
            self.lastUpdated = Date()
        } catch {
            self.errorText = "Failed to refresh: \(error.localizedDescription)"
        }
    }

    func startAutoRefresh(every seconds: UInt64 = 60) {
        stopAutoRefresh()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                // refresh immediately on start, then sleep
                guard let self else { break }
                await self.refresh()
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    // MARK: - Helpers (LandingView uses these)

    func overallMinutes(_ queue: QueueType) -> Int? {
        let items = waitTimes.filter { $0.airport == selectedAirport && $0.queueType == queue }
        if let overall = items.first(where: { $0.terminal == nil }) {
            return overall.minutes
        }
        return items.map(\.minutes).min()
    }

    func jfkTerminalsPresent() -> [Int] {
        guard selectedAirport == .jfk else { return [] }
        let terms = waitTimes
            .filter { $0.airport == .jfk }
            .compactMap { $0.terminal }
        return Array(Set(terms)).sorted()
    }
    
    func jfkMinutes(terminal: Int, category: QueueType) -> Int? {
        guard selectedAirport == .jfk else { return nil }
        return waitTimes.first(where: {
            $0.airport == .jfk && $0.terminal == terminal && $0.queueType == category
        })?.minutes
    }
}
