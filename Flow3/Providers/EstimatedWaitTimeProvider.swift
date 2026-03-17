import Foundation

struct EstimatedWaitTimeProvider: WaitTimeProviding {

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard let profile = EstimatedAirportProfiles.profiles[airport] else {
            return []
        }

        let now = Date()
        let localNow = airportLocalDate(from: now, airport: airport)

        let calendar = Calendar(identifier: .gregorian)
        let hour = calendar.component(.hour, from: localNow)
        let weekday = calendar.component(.weekday, from: localNow)

        let hourAdjustment = hourCurve(for: hour)
        let weekdayAdjustment = weekdayCurve(for: weekday)

        var results: [WaitTimeEstimate] = []

        for checkpoint in profile.checkpoints {
            let isOpen = checkpoint.schedules.contains {
                $0.isOpen(weekday: weekday, hour: hour)
            }

            guard isOpen else { continue }

            if checkpoint.supportsGeneral, let base = checkpoint.generalBaseMinutes {
                let minutes = max(0, smoothed(base + hourAdjustment + weekdayAdjustment))

                results.append(
                    WaitTimeEstimate(
                        airport: airport,
                        terminal: checkpoint.terminal,
                        queueType: .general,
                        minutes: minutes,
                        observedAt: now,
                        checkpointName: checkpoint.name,
                        areaName: checkpoint.areaName,
                        sourceType: .estimated
                    )
                )
            }

            if checkpoint.supportsPrecheck, let base = checkpoint.precheckBaseMinutes {
                let minutes = max(0, smoothed(base + hourAdjustment + weekdayAdjustment - 4))

                results.append(
                    WaitTimeEstimate(
                        airport: airport,
                        terminal: checkpoint.terminal,
                        queueType: .precheck,
                        minutes: minutes,
                        observedAt: now,
                        checkpointName: checkpoint.name,
                        areaName: checkpoint.areaName,
                        sourceType: .estimated
                    )
                )
            }
        }

        return results
    }

    private func airportLocalDate(from date: Date, airport: FlowAirport) -> Date {
        let sourceOffset = TimeZone.current.secondsFromGMT(for: date)
        let destinationOffset = airport.timeZone.secondsFromGMT(for: date)
        let delta = TimeInterval(destinationOffset - sourceOffset)
        return date.addingTimeInterval(delta)
    }

    private func hourCurve(for hour: Int) -> Int {
        switch hour {
        case 4..<6:
            return 4
        case 6..<9:
            return 9
        case 9..<12:
            return 6
        case 12..<15:
            return 3
        case 15..<19:
            return 7
        case 19..<22:
            return 2
        default:
            return 0
        }
    }

    private func weekdayCurve(for weekday: Int) -> Int {
        switch weekday {
        case 2:
            return 3
        case 5:
            return 2
        case 6:
            return 4
        case 1:
            return 3
        default:
            return 0
        }
    }

    private func smoothed(_ value: Int) -> Int {
        Int((Double(value) / 1.0).rounded())
    }
}
