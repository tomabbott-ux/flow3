import Foundation

extension LandingStore {

    func availableSecurityRoutes(for airport: FlowAirport) -> [SecurityRouteOption] {
        let airportWaits = allWaitTimes()
            .filter { $0.airport == airport }

        let built = buildSecurityRouteOptions(from: airportWaits, airport: airport)

        if built.isEmpty {
            return [fallbackSecurityRouteOption(for: airport)]
        }

        return built.sorted { lhs, rhs in
            if lhs.minutes == rhs.minutes {
                return lhs.title < rhs.title
            }
            return lhs.minutes < rhs.minutes
        }
    }

    func plannerSecuritySelection(
        for airport: FlowAirport,
        flightTerminal: String?,
        preferredRouteID: String?
    ) -> PlannerSecuritySelection {

        let allRoutes = availableSecurityRoutes(for: airport)

        if let preferredRouteID,
           let preferred = allRoutes.first(where: { $0.id == preferredRouteID }) {
            return PlannerSecuritySelection(option: preferred, mode: .manual)
        }

        let terminalText = normalizedTerminalText(from: flightTerminal)

        if let terminalText,
           let terminalMatch = allRoutes.first(where: {
               $0.subtitle.localizedCaseInsensitiveContains("Terminal \(terminalText)") ||
               $0.detail.localizedCaseInsensitiveContains("Terminal \(terminalText)") ||
               $0.title.localizedCaseInsensitiveContains("Terminal \(terminalText)")
           }) {
            return PlannerSecuritySelection(option: terminalMatch, mode: .auto)
        }

        if let best = allRoutes.min(by: { $0.minutes < $1.minutes }) {
            return PlannerSecuritySelection(option: best, mode: .auto)
        }

        return PlannerSecuritySelection(
            option: fallbackSecurityRouteOption(for: airport),
            mode: .auto
        )
    }

    func setTrackedFlightSecurityRoute(_ routeID: String?) {
        guard let current = trackedFlight else { return }

        let selection = plannerSecuritySelection(
            for: selectedAirport,
            flightTerminal: current.terminal,
            preferredRouteID: routeID
        )

        let updated = TrackedFlight(
            flightNumber: current.flightNumber,
            route: current.route,
            airline: current.airline,
            terminal: current.terminal,
            gate: current.gate,
            status: current.status,
            departureTime: current.departureTime,
            leaveTime: current.leaveTime,
            gateTargetTime: current.gateTargetTime,
            travelMinutes: current.travelMinutes,
            securityMinutes: max(0, selection.option.minutes),
            airportBufferMinutes: current.airportBufferMinutes,
            bagBufferMinutes: current.bagBufferMinutes,
            leaveTimeTrend: current.leaveTimeTrend,
            securityRouteMode: routeID == nil ? .auto : .manual,
            securityRouteID: routeID == nil ? nil : selection.option.id,
            securityRouteTitle: selection.option.title,
            securityRouteSubtitle: selection.option.subtitle,
            securityRouteDetail: routeID == nil
                ? selection.option.detail
                : "\(selection.option.detail) · Chosen by you",
            securityRouteIsPreCheckOnly: selection.option.isPreCheckOnly
        )

        trackedFlight = updated
        SavedFlightStore.shared.save(updated)
        FlowWatchConnectivityManager.shared.syncTrackedFlight(updated)

        Task {
            await FlowLiveActivityManager.shared.update(for: updated)
        }

        rebuildAlerts()
    }
}

// MARK: - Helpers

private extension LandingStore {

    func buildSecurityRouteOptions(
        from waits: [WaitTimeEstimate],
        airport: FlowAirport
    ) -> [SecurityRouteOption] {

        let openWaits = waits.filter { !$0.isClosed }

        if openWaits.isEmpty {
            return []
        }

        return openWaits.map { item in
            let terminalText = item.terminal.map { "Terminal \($0)" } ?? airport.rawValue
            let checkpointText = cleanedText(item.checkpointName) ?? item.queueType.displayTitle

            let title = checkpointText
            let subtitle = terminalText

            let detail: String = {
                if item.queueType == .precheck {
                    return "\(terminalText) · PreCheck"
                } else {
                    return "\(terminalText) · Security"
                }
            }()

            let isPreCheckOnly = item.queueType == .precheck

            let id = [
                airport.rawValue,
                terminalText,
                checkpointText,
                item.queueType.rawValue
            ]
            .joined(separator: "|")

            return SecurityRouteOption(
                id: id,
                title: title,
                subtitle: subtitle,
                detail: detail,
                minutes: max(0, item.minutes),
                isPreCheckOnly: isPreCheckOnly
            )
        }
    }

    func fallbackSecurityRouteOption(for airport: FlowAirport) -> SecurityRouteOption {
        SecurityRouteOption(
            id: "\(airport.rawValue)|fallback|general",
            title: "Security",
            subtitle: airport.displayName,
            detail: "\(airport.displayName) · Default route",
            minutes: overallMinutes(.general) ?? 15,
            isPreCheckOnly: false
        )
    }

    func normalizedTerminalText(from terminal: String?) -> String? {
        guard let terminal else { return nil }

        let trimmed = terminal
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("T") {
            return String(trimmed.dropFirst())
        }

        return trimmed
    }

    func cleanedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
