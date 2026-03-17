import Foundation

extension LandingStore {

    func availableSecurityRoutes(
        for airport: FlowAirport? = nil
    ) -> [SecurityRouteOption] {
        let airport = airport ?? selectedAirport
        let rows = allWaitTimes()
            .filter { $0.airport == airport && !$0.isClosed }

        let grouped = Dictionary(grouping: rows) { routeGroupingKey(for: $0) }

        return grouped
            .compactMap { key, items in
                makeSecurityRouteOption(
                    airport: airport,
                    key: key,
                    items: items
                )
            }
            .sorted { lhs, rhs in
                if lhs.subtitle == rhs.subtitle {
                    if lhs.minutes == rhs.minutes {
                        return lhs.title < rhs.title
                    }
                    return lhs.minutes < rhs.minutes
                }
                return lhs.subtitle < rhs.subtitle
            }
    }

    func plannerSecuritySelection(
        for airport: FlowAirport? = nil,
        flightTerminal: String? = nil,
        preferredRouteID: String? = nil
    ) -> PlannerSecuritySelection {

        let airport = airport ?? selectedAirport
        let options = availableSecurityRoutes(for: airport)

        let preferPreCheck = UserDefaults.standard.bool(forKey: "flow_prefer_precheck")

        if let preferredRouteID,
           let manual = options.first(where: { $0.id == preferredRouteID }) {
            return PlannerSecuritySelection(
                mode: .manual,
                option: manual,
                source: .manual
            )
        }

        if let matched = automaticTerminalMatchedSelection(
            airport: airport,
            options: options,
            flightTerminal: flightTerminal,
            preferPreCheck: preferPreCheck
        ) {
            return matched
        }

        if preferPreCheck,
           let fastestPreCheck = options
            .filter({ $0.isPreCheckOnly })
            .min(by: { $0.minutes < $1.minutes }) {

            let fallbackOption = SecurityRouteOption(
                id: fastestPreCheck.id,
                title: fastestPreCheck.title,
                subtitle: fastestPreCheck.subtitle,
                detail: fastestPreCheck.detail,
                minutes: fastestPreCheck.minutes,
                isPreCheckOnly: true
            )

            return PlannerSecuritySelection(
                mode: .automatic,
                option: fallbackOption,
                source: .fastestFallback
            )
        }

        if let fastestNonPreCheck = options
            .filter({ !$0.isPreCheckOnly })
            .min(by: { $0.minutes < $1.minutes }) {

            let fallbackOption = SecurityRouteOption(
                id: fastestNonPreCheck.id,
                title: "Fastest available",
                subtitle: fastestNonPreCheck.subtitle,
                detail: fallbackDetail(
                    airport: airport,
                    flightTerminal: flightTerminal,
                    originalOption: fastestNonPreCheck
                ),
                minutes: fastestNonPreCheck.minutes,
                isPreCheckOnly: fastestNonPreCheck.isPreCheckOnly
            )

            return PlannerSecuritySelection(
                mode: .automatic,
                option: fallbackOption,
                source: .fastestFallback
            )
        }

        let fallback = options.min(by: { $0.minutes < $1.minutes }) ??
            SecurityRouteOption(
                id: "\(airport.rawValue)-AUTO",
                title: "Fastest available",
                subtitle: "",
                detail: "Flow automatically selected the fastest checkpoint",
                minutes: 0,
                isPreCheckOnly: false
            )

        return PlannerSecuritySelection(
            mode: .automatic,
            option: fallback,
            source: .fastestFallback
        )
    }

    func setTrackedFlightSecurityRoute(_ routeID: String?) {
        guard let current = trackedFlight else { return }

        let selection = plannerSecuritySelection(
            for: selectedAirport,
            flightTerminal: current.terminal,
            preferredRouteID: routeID
        )

        let checkedBags = current.bagBufferMinutes > 0

        let plan = DeparturePlanner.makePlan(
            departureTime: current.departureTime,
            travelMinutes: current.travelMinutes,
            securityMinutes: max(0, selection.option.minutes),
            checkedBags: checkedBags
        )

        let updated = TrackedFlight(
            flightNumber: current.flightNumber,
            route: current.route,
            airline: current.airline,
            terminal: current.terminal,
            gate: current.gate,
            departureTime: current.departureTime,
            leaveTime: plan.recommendedLeaveTime,
            gateTargetTime: plan.gateTargetTime,
            travelMinutes: current.travelMinutes,
            securityMinutes: selection.option.minutes,
            airportBufferMinutes: plan.airportBufferMinutes,
            bagBufferMinutes: plan.bagBufferMinutes,
            leaveTimeTrend: current.leaveTimeTrend,
            securityRouteMode: selection.mode,
            securityRouteID: selection.mode == .manual ? selection.option.id : nil,
            securityRouteTitle: selection.option.title,
            securityRouteSubtitle: selection.option.subtitle,
            securityRouteDetail: selection.mode == .manual
                ? "\(selection.option.detail) · Chosen by you"
                : selection.option.detail,
            securityRouteIsPreCheckOnly: selection.option.isPreCheckOnly
        )

        trackedFlight = updated
        SavedFlightStore.shared.save(updated)

        Task {
            await FlowNotificationManager.shared.requestPermission()
            FlowNotificationManager.shared.scheduleTrackedFlightReminders(for: updated)
            await FlowLiveActivityManager.shared.update(for: updated)
        }
    }

    private func automaticTerminalMatchedSelection(
        airport: FlowAirport,
        options: [SecurityRouteOption],
        flightTerminal: String?,
        preferPreCheck: Bool
    ) -> PlannerSecuritySelection? {

        let normalizedTerminal = normalizePlannerTerminal(flightTerminal)
        guard let normalizedTerminal else { return nil }

        if airport == .atl {
            if isATLInternationalTerminal(normalizedTerminal) {

                if preferPreCheck,
                   let internationalPreCheck = options
                    .filter({
                        $0.isPreCheckOnly &&
                        routeMatchesInternational($0)
                    })
                    .min(by: { $0.minutes < $1.minutes }) {
                    return PlannerSecuritySelection(
                        mode: .automatic,
                        option: internationalPreCheck,
                        source: .airportSpecific
                    )
                }

                if let international = options
                    .filter({
                        !$0.isPreCheckOnly &&
                        routeMatchesInternational($0)
                    })
                    .min(by: { $0.minutes < $1.minutes }) {

                    return PlannerSecuritySelection(
                        mode: .automatic,
                        option: international,
                        source: .airportSpecific
                    )
                }
            }

            if preferPreCheck,
               let domesticPreCheck = options
                .filter({
                    $0.isPreCheckOnly &&
                    routeMatchesDomestic($0)
                })
                .min(by: { $0.minutes < $1.minutes }) {
                return PlannerSecuritySelection(
                    mode: .automatic,
                    option: domesticPreCheck,
                    source: .airportSpecific
                )
            }

            if let domestic = options
                .filter({
                    !$0.isPreCheckOnly &&
                    routeMatchesDomestic($0)
                })
                .min(by: { $0.minutes < $1.minutes }) {

                return PlannerSecuritySelection(
                    mode: .automatic,
                    option: domestic,
                    source: .airportSpecific
                )
            }
        }

        let candidateTokens = plannerTerminalTokens(from: normalizedTerminal)

        if preferPreCheck,
           let matchedPreCheck = options
            .filter({
                $0.isPreCheckOnly &&
                route($0, matchesAnyTerminalToken: candidateTokens)
            })
            .min(by: { $0.minutes < $1.minutes }) {
            return PlannerSecuritySelection(
                mode: .automatic,
                option: matchedPreCheck,
                source: .terminalMatched
            )
        }

        if let matched = options
            .filter({
                !$0.isPreCheckOnly &&
                route($0, matchesAnyTerminalToken: candidateTokens)
            })
            .min(by: { $0.minutes < $1.minutes }) {
            return PlannerSecuritySelection(
                mode: .automatic,
                option: matched,
                source: .terminalMatched
            )
        }

        if preferPreCheck,
           let relaxedPreCheck = options
            .filter({
                $0.isPreCheckOnly &&
                relaxedRouteMatch($0, terminal: normalizedTerminal)
            })
            .min(by: { $0.minutes < $1.minutes }) {
            return PlannerSecuritySelection(
                mode: .automatic,
                option: relaxedPreCheck,
                source: .terminalMatched
            )
        }

        if let relaxed = options
            .filter({
                !$0.isPreCheckOnly &&
                relaxedRouteMatch($0, terminal: normalizedTerminal)
            })
            .min(by: { $0.minutes < $1.minutes }) {
            return PlannerSecuritySelection(
                mode: .automatic,
                option: relaxed,
                source: .terminalMatched
            )
        }

        if let precheckFallback = options
            .filter({
                route($0, matchesAnyTerminalToken: candidateTokens)
            })
            .min(by: { $0.minutes < $1.minutes }) {
            return PlannerSecuritySelection(
                mode: .automatic,
                option: precheckFallback,
                source: .terminalMatched
            )
        }

        return nil
    }

    private func fallbackDetail(
        airport: FlowAirport,
        flightTerminal: String?,
        originalOption: SecurityRouteOption
    ) -> String {

        let routeDescription = originalOption.subtitle.isEmpty
            ? originalOption.title
            : "\(originalOption.title) · \(originalOption.subtitle)"

        guard let terminal = normalizePlannerTerminal(flightTerminal) else {
            return "Flow selected the quickest checkpoint based on current wait times"
        }

        return "Terminal \(terminal) checkpoint data unavailable. Use \(routeDescription)"
    }

    private func routeGroupingKey(for row: WaitTimeEstimate) -> String {
        let checkpoint = row.checkpointName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let area = row.areaName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let terminal = row.terminal.map { "T\($0)" } ?? ""
        return "\(checkpoint)|\(area)|\(terminal)"
    }

    private func makeSecurityRouteOption(
        airport: FlowAirport,
        key: String,
        items: [WaitTimeEstimate]
    ) -> SecurityRouteOption? {

        let generalMinutes = items
            .filter { $0.queueType == .general }
            .map(\.minutes)
            .min()

        let preCheckMinutes = items
            .filter { $0.queueType == .precheck }
            .map(\.minutes)
            .min()

        guard let minutes = generalMinutes ?? preCheckMinutes else {
            return nil
        }

        let sample = items.first

        let checkpoint = sample?.checkpointName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let area = sample?.areaName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let title: String
        if !checkpoint.isEmpty {
            title = checkpoint
        } else if let terminal = sample?.terminal {
            title = "Terminal \(terminal)"
        } else {
            title = "Security"
        }

        let subtitle: String
        if !area.isEmpty {
            subtitle = area
        } else if let terminal = sample?.terminal {
            subtitle = "Terminal \(terminal)"
        } else {
            subtitle = ""
        }

        let isPreCheckOnly = generalMinutes == nil && preCheckMinutes != nil

        let detail: String
        if isPreCheckOnly {
            detail = subtitle.isEmpty
                ? "\(title) · PreCheck only"
                : "\(title) · \(subtitle) · PreCheck only"
        } else {
            detail = subtitle.isEmpty
                ? title
                : "\(title) · \(subtitle)"
        }

        return SecurityRouteOption(
            id: "\(airport.rawValue)|\(key)".uppercased(),
            title: title,
            subtitle: subtitle,
            detail: detail,
            minutes: minutes,
            isPreCheckOnly: isPreCheckOnly
        )
    }

    private func normalizePlannerTerminal(_ value: String?) -> String? {
        guard let value else { return nil }

        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        return cleaned.isEmpty ? nil : cleaned
    }

    private func plannerTerminalTokens(from terminal: String) -> [String] {
        var tokens: [String] = [terminal]

        let digits = terminal.filter(\.isNumber)
        if !digits.isEmpty {
            tokens.append(digits)
            tokens.append("T\(digits)")
            tokens.append("TERMINAL \(digits)")
        }

        if terminal.hasPrefix("T") {
            let withoutT = String(terminal.dropFirst())
            if !withoutT.isEmpty {
                tokens.append(withoutT)
                tokens.append("TERMINAL \(withoutT)")
            }
        }

        if terminal.hasPrefix("TERMINAL ") {
            let withoutWord = terminal.replacingOccurrences(of: "TERMINAL ", with: "")
            if !withoutWord.isEmpty {
                tokens.append(withoutWord)
                tokens.append("T\(withoutWord)")
            }
        }

        return Array(Set(tokens))
    }

    private func route(
        _ option: SecurityRouteOption,
        matchesAnyTerminalToken tokens: [String]
    ) -> Bool {
        let haystack = routeSearchText(for: option)

        for token in tokens {
            if haystack.contains(token) {
                return true
            }
        }

        return false
    }

    private func relaxedRouteMatch(
        _ option: SecurityRouteOption,
        terminal: String
    ) -> Bool {
        let haystack = routeSearchText(for: option)

        if haystack.contains("TERMINAL") && haystack.contains(terminal) {
            return true
        }

        let digits = terminal.filter(\.isNumber)
        if !digits.isEmpty {
            if haystack.contains("TERMINAL \(digits)") { return true }
            if haystack.contains("T\(digits)") { return true }
        }

        return false
    }

    private func routeSearchText(for option: SecurityRouteOption) -> String {
        [
            option.title,
            option.subtitle,
            option.detail
        ]
        .joined(separator: " ")
        .uppercased()
    }

    private func routeMatchesDomestic(_ option: SecurityRouteOption) -> Bool {
        let haystack = routeSearchText(for: option)
        return haystack.contains("DOMESTIC")
    }

    private func routeMatchesInternational(_ option: SecurityRouteOption) -> Bool {
        let haystack = routeSearchText(for: option)
        return haystack.contains("INTERNATIONAL") || haystack.contains("INTL")
    }

    private func isATLInternationalTerminal(_ terminal: String?) -> Bool {
        guard let terminal else { return false }

        if terminal == "I" { return true }
        if terminal == "INTL" { return true }
        if terminal == "INTERNATIONAL" { return true }
        if terminal.contains("INTL") { return true }
        if terminal.contains("INTERNATIONAL") { return true }

        return false
    }
}

