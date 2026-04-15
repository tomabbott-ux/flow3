import Foundation

extension LandingStore {

    func availableSecurityRoutes(for airport: FlowAirport) -> [SecurityRouteOption] {
        let airportWaits = waitTimes(for: airport)

        let built = buildSecurityRouteOptions(
            from: airportWaits,
            airport: airport
        )

        if !built.isEmpty {
            return built.sorted { lhs, rhs in
                if lhs.minutes == rhs.minutes {
                    return lhs.title < rhs.title
                }
                return lhs.minutes < rhs.minutes
            }
        }

        return [fallbackSecurityRouteOption(for: airport)]
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
        let preferPreCheck = UserDefaults.standard.bool(forKey: "flow_prefer_precheck")

        let terminalMatches: [SecurityRouteOption]

        if airport == .atl, let terminalText {
            terminalMatches = allRoutes.filter { route in
                atlRouteMatch(for: terminalText, in: [route]) != nil
            }
        } else if let terminalText {
            terminalMatches = allRoutes.filter { route in
                routeMatchesTerminal(
                    route,
                    airport: airport,
                    terminalText: terminalText
                )
            }
        } else {
            terminalMatches = []
        }

        let candidateRoutes = terminalMatches.isEmpty ? allRoutes : terminalMatches
        
        let generalRoutes = candidateRoutes.filter { !$0.isPreCheckOnly }
        let precheckRoutes = candidateRoutes.filter { $0.isPreCheckOnly }
        
        if preferPreCheck,
           let bestPrecheck = precheckRoutes.min(by: { $0.minutes < $1.minutes }) {
            return PlannerSecuritySelection(option: bestPrecheck, mode: .auto)
        }
        
        if let bestGeneral = generalRoutes.min(by: { $0.minutes < $1.minutes }) {
            return PlannerSecuritySelection(option: bestGeneral, mode: .auto)
        }
        
        if let bestPrecheck = precheckRoutes.min(by: { $0.minutes < $1.minutes }) {
            return PlannerSecuritySelection(option: bestPrecheck, mode: .auto)
        }
        
        if let terminalText,
           let smartFallback = bestFallbackRouteMatch(
                airport: airport,
                terminalText: terminalText,
                in: allRoutes
           ) {
            return PlannerSecuritySelection(option: smartFallback, mode: .auto)
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
        
        let trackedAirport = flowAirport(from: current.route.components(separatedBy: "→").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? selectedAirport
        
        
        let selection = plannerSecuritySelection(
            for: trackedAirport,
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
            securityRouteID: selection.option.id,
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
    
    func refreshTrackedFlightSecurityIfNeeded() {
        guard let current = trackedFlight else { return }
        
        let trackedAirport = flowAirport(from: current.route.components(separatedBy: "→").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? selectedAirport
    
        
        let selection = plannerSecuritySelection(
            for: trackedAirport,
            flightTerminal: current.terminal,
            preferredRouteID: current.securityRouteMode == .manual ? current.securityRouteID : nil
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
            securityRouteMode: current.securityRouteMode,
            securityRouteID: selection.option.id,
            securityRouteTitle: selection.option.title,
            securityRouteSubtitle: selection.option.subtitle,
            securityRouteDetail: selection.option.detail,
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
        
        var options: [SecurityRouteOption] = []
        
        for row in rows {
            let detail = buildDetailText(
                airport: airport,
                rowTitle: row.title,
                rowSubtitle: row.subtitle,
                metrics: row.metrics
            )
            
            let generalMinutes = row.metrics.first(where: {
                $0.label.localizedCaseInsensitiveContains("General") ||
                $0.label.localizedCaseInsensitiveContains("Wait")
            })?.minutes
            
            let precheckMinutes = row.metrics.first(where: {
                $0.label.localizedCaseInsensitiveContains("PreCheck")
            })?.minutes
            
            if let generalMinutes {
                options.append(
                    SecurityRouteOption(
                        id: "\(row.id)|general",
                        title: row.title,
                        subtitle: row.subtitle,
                        detail: detail,
                        minutes: max(0, generalMinutes),
                        isPreCheckOnly: false
                    )
                )
            }
            
            if let precheckMinutes {
                options.append(
                    SecurityRouteOption(
                        id: "\(row.id)|precheck",
                        title: row.title,
                        subtitle: row.subtitle,
                        detail: detail,
                        minutes: max(0, precheckMinutes),
                        isPreCheckOnly: true
                    )
                )
            }
        }
        
        return options
    }
    
    func displayRowsForSecurityMatching(
        from waits: [WaitTimeEstimate],
        airport: FlowAirport
    ) -> [AirportDisplayRow] {

        let hasUsableTerminalData = waits.contains { row in
            if let terminal = row.terminal, terminal > 0 {
                return true
            }

            let checkpoint = (row.checkpointName ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let area = (row.areaName ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            return checkpoint.contains("terminal") || area.contains("terminal")
        }

        if hasUsableTerminalData {
            return terminalStyleDisplayRows(from: waits, airport: airport)
        }

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
    
    func atlRouteMatch(
        for terminalText: String,
        in routes: [SecurityRouteOption]
    ) -> SecurityRouteOption? {
        
        let value = terminalText.uppercased()
        
        if value == "N" || value == "NORTH" {
            return routes.first(where: {
                $0.title.localizedCaseInsensitiveContains("NORTH")
            })
        }
        
        if value == "S" || value == "SOUTH" {
            return routes.first(where: {
                $0.title.localizedCaseInsensitiveContains("SOUTH")
            })
        }
        
        if value == "MAIN" || value == "M" {
            return routes.first(where: {
                $0.title.localizedCaseInsensitiveContains("MAIN") &&
                $0.subtitle.localizedCaseInsensitiveContains("DOMESTIC")
            }) ?? routes.first(where: {
                $0.title.localizedCaseInsensitiveContains("MAIN")
            })
        }
        
        if value == "1" || value == "DOMESTIC" || value == "D" {
            let domesticRoutes = routes.filter {
                $0.subtitle.localizedCaseInsensitiveContains("DOMESTIC")
            }
            return domesticRoutes.min(by: { $0.minutes < $1.minutes })
        }
        
        if value == "2" || value == "INTERNATIONAL" || value == "I" {
            let internationalRoutes = routes.filter {
                $0.subtitle.localizedCaseInsensitiveContains("INTERNATIONAL")
            }
            return internationalRoutes.min(by: { $0.minutes < $1.minutes })
        }
        
        return nil
    }

    func routeMatchesTerminal(
        _ route: SecurityRouteOption,
        airport: FlowAirport,
        terminalText: String
    ) -> Bool {
        
        let normalizedRouteText = [
            route.title,
            route.subtitle,
            route.detail
        ]
        .joined(separator: " ")
        .uppercased()
        
        let value = terminalText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        
        if airport == .lax {
            return laxRouteMatchesTerminal(
                normalizedRouteText: normalizedRouteText,
                terminalText: value
            )
        }
        
        let variants = terminalVariants(for: value)
        
        return variants.contains { variant in
            normalizedRouteText.contains(variant)
        }
    }

    func terminalVariants(for terminalText: String) -> [String] {
        let value = terminalText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        
        var variants: [String] = [
            "TERMINAL \(value)",
            "TERMINAL T\(value)",
            "T\(value)"
        ]
        
        if value.hasPrefix("T") {
            let raw = String(value.dropFirst())
            variants.append("TERMINAL \(raw)")
        }
        
        return Array(Set(variants))
    }

    func laxRouteMatchesTerminal(
        normalizedRouteText: String,
        terminalText: String
    ) -> Bool {
        
        let value = terminalText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        
        let laxTerminalMap: [String: [String]] = [
            "B": [
                "TERMINAL B",
                "TOM BRADLEY",
                "TBIT",
                "TERMINAL TBIT"
            ],
            "TBIT": [
                "TERMINAL B",
                "TOM BRADLEY",
                "TBIT",
                "TERMINAL TBIT"
            ],
            "TOM BRADLEY": [
                "TERMINAL B",
                "TOM BRADLEY",
                "TBIT",
                "TERMINAL TBIT"
            ],
            "1": ["TERMINAL 1", "T1"],
            "2": ["TERMINAL 2", "T2"],
            "3": ["TERMINAL 3", "T3"],
            "4": ["TERMINAL 4", "T4"],
            "5": ["TERMINAL 5", "T5"],
            "6": ["TERMINAL 6", "T6"],
            "7": ["TERMINAL 7", "T7"],
            "8": ["TERMINAL 8", "T8"]
        ]
        
        let lookupKey: String = {
            if value == "TERMINAL B" { return "B" }
            if value == "TERMINAL TBIT" { return "TBIT" }
            if value == "TOMBRADLEY" || value == "TOM BRADLEY" { return "TOM BRADLEY" }
            if value.hasPrefix("TERMINAL ") {
                return value.replacingOccurrences(of: "TERMINAL ", with: "")
            }
            if value.hasPrefix("T"), value.count == 2 {
                return String(value.dropFirst())
            }
            return value
        }()
        
        guard let variants = laxTerminalMap[lookupKey] else {
            return terminalVariants(for: value).contains { normalizedRouteText.contains($0) }
        }
        
        return variants.contains { alias in
            normalizedRouteText.contains(alias)
        }
    }
    
    func bestFallbackRouteMatch(
        airport: FlowAirport,
        terminalText: String,
        in routes: [SecurityRouteOption]
    ) -> SecurityRouteOption? {
        
        let strictTerminalMatches = routes.filter {
            routeMatchesTerminal(
                $0,
                airport: airport,
                terminalText: terminalText
            )
        }
        
        if let bestStrict = strictTerminalMatches.min(by: { $0.minutes < $1.minutes }) {
            return bestStrict
        }
        
        if airport == .atl {
            let value = terminalText.uppercased()
            
            if value == "N" || value == "S" || value == "MAIN" || value == "D" || value == "DOMESTIC" {
                let domesticRoutes = routes.filter {
                    $0.subtitle.localizedCaseInsensitiveContains("DOMESTIC")
                }
                
                if let bestDomestic = domesticRoutes.min(by: { $0.minutes < $1.minutes }) {
                    return bestDomestic
                }
            }
        }
        
        return routes.min(by: { $0.minutes < $1.minutes })
    }
}
