import SwiftUI

struct TrackedFlightPill: View {

    @ObservedObject var store: LandingStore

    @State private var expanded = false
    @State private var isRefreshing = false
    @State private var showingRoutePicker = false

    private let refreshTimer = Timer.publish(every: 120, on: .main, in: .common).autoconnect()

    private var availableRoutes: [SecurityRouteOption] {
        guard let flight = store.trackedFlight,
              let airport = flowAirport(for: flight) else {
            return []
        }

        return store.availableSecurityRoutes(for: airport)
    }

    var body: some View {
        Group {
            if let flight = store.trackedFlight {
                VStack(alignment: .leading, spacing: 16) {
                    headerButton(for: flight)

                    if expanded {
                        expandedContent(for: flight)
                    }
                }
                .padding(20)
                .background(cardBackground)
                .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
                
                .onReceive(refreshTimer) { _ in
                    Task {
                        await store.refreshTrackedFlight()
                    }
                }
                .confirmationDialog(
                    "Choose security checkpoint",
                    isPresented: $showingRoutePicker,
                    titleVisibility: .visible
                ) {
                    if usesFlowAirport(flight) {
                        Button("Auto") {
                            store.setTrackedFlightSecurityRoute(nil)
                        }

                        ForEach(availableRoutes) { route in
                            Button(routePickerTitle(for: route)) {
                                store.setTrackedFlightSecurityRoute(route.id)
                            }
                        }
                    }

                    Button("Cancel", role: .cancel) { }
                }
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.16),
                        Color.white.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }

    private func headerButton(for flight: TrackedFlight) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                expanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                headerTopBar
                titleRow(for: flight)
                statusBadge(for: flight)
                leaveTimeBlock(for: flight)
                summaryRow(for: flight)
            }
        }
        .buttonStyle(.plain)
    }

    private var headerTopBar: some View {
        HStack {
            HStack(spacing: 8) {

                // Static dot (no animation)
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)

                Text("Tracking Flight")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.green.opacity(0.95))
            }

            Spacer()

            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private func titleRow(for flight: TrackedFlight) -> some View {
        Text("\(flight.flightNumber) • \(flight.route)")
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.white)
    }

    private func statusBadge(for flight: TrackedFlight) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(for: flight))
                .frame(width: 8, height: 8)

            Text(displayStatus(for: flight))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(statusColor(for: flight))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(statusColor(for: flight).opacity(0.14))
                .overlay(
                    Capsule()
                        .stroke(statusColor(for: flight).opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func leaveTimeBlock(for flight: TrackedFlight) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))

                Text("Leave at")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }

            Text(timeString(flight.leaveTime))
                .font(.system(size: 42, weight: .heavy))
                .foregroundColor(leaveTimeColor(for: flight.leaveTimeTrend))
                .monospacedDigit()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                if flight.leaveTime > context.date {
                    Text("Leaving in \(countdownString(until: flight.leaveTime, now: context.date))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.78))
                        .monospacedDigit()
                } else {
                    Text("Leave now")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.red.opacity(0.95))
                }
            }
        }
    }

    private func summaryRow(for flight: TrackedFlight) -> some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "airplane")
                Text(timeString(flight.departureTime))
            }

            HStack(spacing: 6) {
                Image(systemName: "building.2")
                Text(displayTerminalCompact(flight.terminal, for: flight))
            }

            if usesFlowAirport(flight) {
                HStack(spacing: 6) {
                    Image(systemName: "suitcase")
                    Text(securityRouteSummary(for: flight))
                }
            }

            Spacer()
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.white.opacity(0.85))
    }

    private func expandedContent(for flight: TrackedFlight) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
                .overlay(Color.white.opacity(0.12))

            infoRow("Airline", flight.airline)
            infoRow("Status", displayStatus(for: flight))
            infoRow("Terminal", displayTerminalExpanded(flight.terminal, for: flight))
            infoRow("Gate", displayGateExpanded(flight.gate))
            infoRow("Departure", timeString(flight.departureTime))
            infoRow("Leave at", timeString(flight.leaveTime))
            infoRow("Gate target", timeString(flight.gateTargetTime))

            Divider()
                .overlay(Color.white.opacity(0.10))

            if usesFlowAirport(flight) {
                infoRow("Security route", securityRouteValueText(for: flight))

                Text(flight.securityRouteDetail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.68))

                Button {
                    showingRoutePicker = true
                } label: {
                    Text("Change checkpoint")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Color.white.opacity(0.10))

                infoRow("Journey time", "\(flight.travelMinutes)m")
                infoRow("Security wait", "\(flight.securityMinutes)m")
                infoRow("Airport buffer", "\(flight.airportBufferMinutes)m")
            } else {
                infoRow("Journey time", "\(flight.travelMinutes)m")
                infoRow("Airport buffer", "\(flight.airportBufferMinutes)m")
                infoRow("Security", "Not supported")

                Text("Flow does not yet provide checkpoint timing for this airport. Leave planning uses your travel time and standard buffers only.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.68))

                Divider()
                    .overlay(Color.white.opacity(0.10))
            }

            if flight.bagBufferMinutes > 0 {
                infoRow("Bag drop buffer", "\(flight.bagBufferMinutes)m")
            }

            let totalBeforeAirport =
                flight.travelMinutes +
                flight.securityMinutes +
                flight.airportBufferMinutes +
                flight.bagBufferMinutes

            infoRow("Total pre-airport time", "\(totalBeforeAirport)m")

            HStack(spacing: 12) {
                Button {
                    Task {
                        isRefreshing = true
                        await store.refreshTrackedFlight()
                        isRefreshing = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isRefreshing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }

                        Text("Refresh")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    store.clearTrackedFlight()
                } label: {
                    Text("Stop tracking")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red.opacity(0.95))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }

    private func usesFlowAirport(_ flight: TrackedFlight) -> Bool {
        let code = departureAirportCode(for: flight)

        return AirportRegistry.airports.contains {
            $0.airport.rawValue.caseInsensitiveCompare(code) == .orderedSame
        }
    }

    private func departureAirportCode(for flight: TrackedFlight) -> String {
        flight.route
            .components(separatedBy: "→")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
    }

    private func flowAirport(for flight: TrackedFlight) -> FlowAirport? {
        let code = departureAirportCode(for: flight)

        return AirportRegistry.airports
            .map(\.airport)
            .first(where: { $0.rawValue.caseInsensitiveCompare(code) == .orderedSame })
    }

    private func securityRouteValueText(for flight: TrackedFlight) -> String {
        let base = flight.securityRouteSubtitle.isEmpty
            ? flight.securityRouteTitle
            : "\(flight.securityRouteTitle) • \(flight.securityRouteSubtitle)"

        if flight.securityRouteMode == .manual {
            return "\(base) • Chosen by you"
        }

        return base
    }

    private func securityRouteSummary(for flight: TrackedFlight) -> String {
        if !flight.securityRouteTitle.isEmpty {
            return flight.securityRouteTitle
        }

        return "Security"
    }

    private func routePickerTitle(for route: SecurityRouteOption) -> String {
        let base = route.subtitle.isEmpty
            ? "\(route.title) • \(route.minutes)m"
            : "\(route.title) • \(route.subtitle) • \(route.minutes)m"

        if route.isPreCheckOnly {
            return "\(base) • PreCheck only"
        }

        return base
    }

    private func displayStatus(for flight: TrackedFlight) -> String {
        let raw = flight.status?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if raw.isEmpty {
            return "On Time"
        }

        let normalized = raw.lowercased()

        switch normalized {
        case "unknown", "na", "n/a":
            return "On Time"
        case "expected", "scheduled", "active":
            return "On Time"
        case "boarding":
            return "Boarding"
        case "gateopen", "gate_open", "gate open":
            return "Gate Open"
        case "gateclosed", "gate_closed", "gate closed", "finalcall", "final_call", "final call":
            return "Gate Closing"
        case "delayed":
            return "Delayed"
        case "departed":
            return "Departed"
        case "landed", "arrived":
            return "Arrived"
        case "cancelled":
            return "Cancelled"
        case "incident", "diverted":
            return "Disrupted"
        default:
            return raw
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(
                    of: "([a-z])([A-Z])",
                    with: "$1 $2",
                    options: .regularExpression
                )
                .capitalized
        }
    }

    private func statusColor(for flight: TrackedFlight) -> Color {
        let raw = flight.status?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        switch raw {
        case "", "unknown", "na", "n/a",
             "expected", "scheduled", "active",
             "gateopen", "gate_open", "gate open":
            return .green
        case "boarding":
            return .yellow
        case "gateclosed", "gate_closed", "gate closed",
             "finalcall", "final_call", "final call",
             "delayed":
            return .red
        case "departed", "arrived", "landed":
            return .white.opacity(0.9)
        default:
            return .white.opacity(0.85)
        }
    }

    private func leaveTimeColor(for trend: LeaveTimeTrend) -> Color {
        switch trend {
        case .unchanged:
            return .white
        case .earlier:
            return .red.opacity(0.95)
        case .later:
            return .green.opacity(0.95)
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.72))

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
    }

    private func displayTerminalCompact(_ terminal: String, for flight: TrackedFlight) -> String {
        if let airport = flowAirport(for: flight) {
            return AirportTerminalFormatter.compactName(for: airport, rawTerminal: terminal)
        }

        return cleanedText(terminal) ?? "TBD"
    }

    private func displayTerminalExpanded(_ terminal: String, for flight: TrackedFlight) -> String {
        if let airport = flowAirport(for: flight) {
            return AirportTerminalFormatter.displayName(for: airport, rawTerminal: terminal)
        }

        return cleanedText(terminal) ?? "TBD"
    }

    private func displayGateExpanded(_ gate: String?) -> String {
        cleanedText(gate) ?? "TBD"
    }

    private func cleanedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "—" {
            return nil
        }
        return trimmed
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func countdownString(until date: Date, now: Date) -> String {
        let totalSeconds = max(0, Int(date.timeIntervalSince(now)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
