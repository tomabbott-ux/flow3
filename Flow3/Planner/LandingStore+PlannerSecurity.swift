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
               $0.title.localizedCaseInsensitiveContains("Terminal \(terminalText)") ||
               $0.subtitle.localizedCaseInsensitiveContains("Terminal \(terminalText)") ||
               $0.detail.localizedCaseInsensitiveContains("Terminal \(terminalText)")
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

        let rows = displayRowsForSecurityMatching(from: openWaits, airport: airport)

        return rows.compactMap { row in
            let bestMinutes = row.metrics.compactMap(\.minutes).min()

            guard let bestMinutes else { return nil }

            let detail = buildDetailText(
                airport: airport,
                rowTitle: row.title,
                rowSubtitle: row.subtitle,
                metrics: row.metrics
            )

            let isPreCheckOnly =
                row.metrics.count == 1 &&
                row.metrics.first?.label.localizedCaseInsensitiveContains("PreCheck") == true

            return SecurityRouteOption(
                id: row.id,
                title: row.title,
                subtitle: row.subtitle,
                detail: detail,
                minutes: max(0, bestMinutes),
                isPreCheckOnly: isPreCheckOnly
            )
        }
    }

    func displayRowsForSecurityMatching(
        from waits: [WaitTimeEstimate],
        airport: FlowAirport
    ) -> [AirportDisplayRow] {
        if airport.prefersCheckpointPresentation {
            return checkpointDisplayRows(from: waits, airport: airport)
        } else {
            return terminalStyleDisplayRows(from: waits, airport: airport)
        }
    }

    func checkpointDisplayRows(
        from rows: [WaitTimeEstimate],
        airport: FlowAirport
    ) -> [AirportDisplayRow] {

        let grouped = Dictionary(grouping: rows) { row in
            let checkpoint = row.checkpointName ?? "Security"
            let area = row.areaName ?? ""
            return "\(checkpoint)|\(area)"
        }

        var displayRows = grouped.map { key, items in
            let parts = key
                .split(separator: "|", omittingEmptySubsequences: false)
                .map(String.init)

            let title = parts.first ?? "Security"
            let subtitle = parts.count > 1 ? parts[1] : ""
            let observedAt = items.map(\.observedAt).max()
            let isClosed = items.allSatisfy(\.isClosed)
            let isLive = items.contains { $0.sourceType == .live }

            let general = items.first(where: { $0.queueType == .general && !$0.isClosed })?.minutes
            let precheck = items.first(where: { $0.queueType == .precheck && !$0.isClosed })?.minutes

            let metrics = metricsForSecurityRow(
                general: general,
                precheck: precheck,
                items: items,
                isClosed: isClosed
            )

            return AirportDisplayRow(
                id: key,
                title: title,
                subtitle: subtitle,
                metrics: metrics,
                observedAt: observedAt,
                isClosed: isClosed,
                isLive: isLive
            )
        }

        if airport == .slc,
           let observedAt = rows.map(\.observedAt).max() {

            displayRows.append(
                AirportDisplayRow(
                    id: "SLC-PRECHECK-AVAILABLE",
                    title: "PreCheck",
                    subtitle: "Available",
                    metrics: [
                        AirportMetric(label: "PreCheck", minutes: nil)
                    ],
                    observedAt: observedAt,
                    isClosed: false,
                    isLive: rows.contains { $0.sourceType == .live }
                )
            )
        }

        displayRows.sort { lhs, rhs in
            if lhs.id == "SLC-PRECHECK-AVAILABLE" { return false }
            if rhs.id == "SLC-PRECHECK-AVAILABLE" { return true }

            if airport == .sea {
                if lhs.isClosed != rhs.isClosed {
                    return rhs.isClosed
                }
            }

            if lhs.title == rhs.title {
                return lhs.subtitle < rhs.subtitle
            }

            return lhs.title < rhs.title
        }

        var seen = Set<String>()
        return displayRows.filter { row in
            let key = row.title + "|" + row.subtitle
            return seen.insert(key).inserted
        }
    }

    func terminalStyleDisplayRows(
        from rows: [WaitTimeEstimate],
        airport: FlowAirport
    ) -> [AirportDisplayRow] {

        let cleanedRows = rows.compactMap { row -> WaitTimeEstimate? in
            if airport == .lax, row.terminal == 0 {
                return WaitTimeEstimate(
                    airport: row.airport,
                    terminal: 999,
                    queueType: row.queueType,
                    minutes: row.minutes,
                    observedAt: row.observedAt,
                    checkpointName: "Tom Bradley International Terminal",
                    areaName: row.areaName,
                    sourceType: row.sourceType,
                    isClosed: row.isClosed
                )
            }

            return row
        }

        let grouped = Dictionary(grouping: cleanedRows) { $0.terminal ?? -1 }

        return grouped
            .compactMap { terminal, items -> AirportDisplayRow? in
                guard terminal >= 0 else { return nil }
                if terminal == 0 { return nil }

                let isTBIT = terminal == 999 && airport == .lax
                let isLive = isTBIT || items.contains { $0.sourceType == .live }

                let title: String = isTBIT ? "Terminal B" : "Terminal \(terminal)"

                let subtitle: String = isTBIT
                    ? "Tom Bradley International Terminal"
                    : cleanedTerminalSubtitle(
                        title: title,
                        subtitle: items.first?.checkpointName ?? "Security"
                    )

                let observedAt = items.map(\.observedAt).max()
                let isClosed = items.allSatisfy(\.isClosed)

                let general = items.first(where: { $0.queueType == .general && !$0.isClosed })?.minutes
                let precheck = items.first(where: { $0.queueType == .precheck && !$0.isClosed })?.minutes

                let metrics: [AirportMetric]

                if isClosed {
                    metrics = [AirportMetric(label: "Closed", minutes: nil)]
                } else if isTBIT {
                    metrics = [
                        AirportMetric(label: "General", minutes: general ?? precheck),
                        AirportMetric(label: "PreCheck", minutes: precheck ?? general)
                    ]
                } else {
                    metrics = metricsForSecurityRow(
                        general: general,
                        precheck: precheck,
                        items: items,
                        isClosed: isClosed
                    )
                }

                return AirportDisplayRow(
                    id: "\(airport.rawValue)-T\(terminal)",
                    title: title,
                    subtitle: subtitle,
                    metrics: metrics,
                    observedAt: observedAt,
                    isClosed: isClosed,
                    isLive: isLive
                )
            }
            .sorted { lhs, rhs in
                if lhs.title == "Terminal B" { return true }
                if rhs.title == "Terminal B" { return false }

                func extractNumber(_ title: String) -> Int {
                    let cleaned = title.replacingOccurrences(of: "Terminal ", with: "")
                    return Int(cleaned) ?? 999
                }

                return extractNumber(lhs.title) < extractNumber(rhs.title)
            }
    }

    func cleanedTerminalSubtitle(title: String, subtitle: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmedSubtitle.isEmpty {
            return "Security"
        }

        if trimmedTitle == trimmedSubtitle {
            return "Security"
        }

        return subtitle
    }

    func metricsForSecurityRow(
        general: Int?,
        precheck: Int?,
        items: [WaitTimeEstimate],
        isClosed: Bool
    ) -> [AirportMetric] {

        if isClosed {
            return [
                AirportMetric(label: "Closed", minutes: nil)
            ]
        }

        if general != nil && precheck != nil {
            return [
                AirportMetric(label: "General", minutes: general),
                AirportMetric(label: "PreCheck", minutes: precheck)
            ]
        }

        if precheck != nil {
            return [
                AirportMetric(label: "PreCheck", minutes: precheck)
            ]
        }

        if general != nil {
            return [
                AirportMetric(label: "Wait", minutes: general)
            ]
        }

        let bestMinutes = items
            .filter { !$0.isClosed }
            .map(\.minutes)
            .min()

        return [
            AirportMetric(label: "Wait", minutes: bestMinutes)
        ]
    }

    func buildDetailText(
        airport: FlowAirport,
        rowTitle: String,
        rowSubtitle: String,
        metrics: [AirportMetric]
    ) -> String {

        let trimmedSubtitle = rowSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if rowTitle.localizedCaseInsensitiveContains("Terminal") {
            if trimmedSubtitle.isEmpty {
                return "\(rowTitle) · Security"
            }
            return "\(rowTitle) · \(trimmedSubtitle)"
        }

        if trimmedSubtitle.localizedCaseInsensitiveContains("Terminal") {
            return "\(trimmedSubtitle) · \(rowTitle)"
        }

        if !trimmedSubtitle.isEmpty {
            return "\(trimmedSubtitle) · \(rowTitle)"
        }

        if metrics.count > 1 {
            return "\(airport.displayName) · \(rowTitle)"
        }

        return "\(airport.displayName) · Security"
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
}
