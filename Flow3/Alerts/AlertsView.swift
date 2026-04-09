import SwiftUI

struct AlertsView: View {
    @ObservedObject var store: LandingStore
    @Binding var selectedTab: FlowRootView.FlowTab

    @State private var pulseCritical = false
    @State private var selectedCalendarFlight: PendingCalendarFlight?
    @State private var trackedFlightExpanded = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                headerCard

                if let trackedFlight = store.trackedFlight {
                    trackedFlightCard(trackedFlight)
                }

                ForEach(calendarFlightAlerts) { alert in
                    Button {
                        handleTap(on: alert)
                    } label: {
                        pendingCalendarCard(alert)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(operationalAlerts) { alert in
                    Button {
                        handleTap(on: alert)
                    } label: {
                        standardAlertCard(alert)
                    }
                    .buttonStyle(.plain)
                }

                if store.trackedFlight == nil && calendarFlightAlerts.isEmpty && operationalAlerts.isEmpty {
                    emptyStateCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "2A0C5A"),
                    Color(hex: "3B136E"),
                    Color(hex: "14062F")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            store.rebuildAlerts()
        }
        .onAppear {
            pulseCritical = true
        }
        .onChange(of: store.selectedAirport) { _ in
            store.rebuildAlerts()
        }
        .onChange(of: store.trackedFlight?.flightNumber) { _, _ in
            store.rebuildAlerts()
        }
        .onChange(of: store.lastUpdated) { _, _ in
            store.rebuildAlerts()
        }
        .sheet(item: $selectedCalendarFlight) { pending in
            calendarFlightSheet(pending)
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(.clear)
        }
        .animation(.easeInOut(duration: 0.25), value: store.alerts)
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: trackedFlightExpanded)
    }
}

// MARK: - Derived alert groups

private extension AlertsView {

    var calendarFlightAlerts: [FlowAlert] {
        store.alerts.filter { $0.kind == .calendarFlightDetected }
    }

    var operationalAlerts: [FlowAlert] {
        store.alerts.filter {
            switch $0.kind {
            case .calendarFlightDetected, .leaveNow, .leaveSoon, .onTrack, .trackedFlight:
                return false
            default:
                return true
            }
        }
    }
}

// MARK: - Header + Empty State

private extension AlertsView {

    var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flow alerts")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text("A calm, useful summary of what matters now.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
        }
        .flowGlassCard()
    }

    var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No alerts right now")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text("Flow will show important flight, security, and tracking updates here.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
        }
        .flowGlassCard()
    }
}

// MARK: - Tracked Flight Card

private extension AlertsView {

    func trackedFlightCard(_ flight: TrackedFlight) -> some View {
        Button {
            trackedFlightExpanded.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.16))
                            .frame(width: 42, height: 42)

                        Image(systemName: "airplane")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green.opacity(0.95))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 8) {
                            Text("Flight tracking")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            trackingPill
                        }

                        Text(trackedRouteLine(for: flight))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.92))

                        Text(trackedStatusSummary(for: flight))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.78))
                    }

                    Spacer(minLength: 0)

                    Image(systemName: trackedFlightExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.top, 4)
                }

                if trackedFlightExpanded {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            compactTag(
                                trackedPrimaryStateTitle(for: flight),
                                tint: trackedPrimaryStateColor(for: flight)
                            )

                            if let status = cleanedStatus(flight.status) {
                                compactTag(status, tint: .white.opacity(0.24))
                            }
                        }

                        HStack(spacing: 12) {
                            detailMetric(title: "Leave", value: formattedTime(flight.leaveTime))
                            detailMetric(title: "Depart", value: formattedTime(flight.departureTime))
                            detailMetric(title: "Airport", value: departureAirportCode(from: flight.route))
                        }

                        HStack(spacing: 12) {
                            if let terminal = cleanedText(flight.terminal) {
                                compactTag("Terminal \(terminal)", tint: .white.opacity(0.16))
                            }

                            if let gate = cleanedText(flight.gate) {
                                compactTag("Gate \(gate)", tint: .white.opacity(0.16))
                            }

                            compactTag("\(flight.securityMinutes)m security", tint: .white.opacity(0.16))
                        }

                        HStack(spacing: 10) {
                            Button {
                                selectedTab = .flight
                            } label: {
                                Text("Open Flight")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        Capsule()
                                            .fill(Color(hex: "9B6CFF").opacity(0.92))
                                    )
                            }
                            .buttonStyle(.plain)

                            Button {
                                store.clearTrackedFlight()
                                trackedFlightExpanded = false
                            } label: {
                                Text("Stop tracking")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.08))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.14),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.green.opacity(0.16), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    var trackingPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: 7, height: 7)

            Text("TRACKING")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.10))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    func trackedRouteLine(for flight: TrackedFlight) -> String {
        "\(flight.flightNumber) · \(flight.route)"
    }

    func trackedStatusSummary(for flight: TrackedFlight) -> String {
        trackedPrimaryStateTitle(for: flight)
    }

    func trackedPrimaryStateTitle(for flight: TrackedFlight) -> String {
        let secondsUntilLeave = flight.leaveTime.timeIntervalSinceNow

        if secondsUntilLeave <= 0 {
            return "Leave now"
        } else if secondsUntilLeave <= 30 * 60 {
            return "Leave soon"
        } else {
            return "On track"
        }
    }

    func trackedPrimaryStateColor(for flight: TrackedFlight) -> Color {
        let secondsUntilLeave = flight.leaveTime.timeIntervalSinceNow

        if secondsUntilLeave <= 0 {
            return .red.opacity(0.9)
        } else if secondsUntilLeave <= 30 * 60 {
            return .orange.opacity(0.9)
        } else {
            return .green.opacity(0.9)
        }
    }
}

// MARK: - Pending Calendar Flight Cards

private extension AlertsView {

    func pendingCalendarCard(_ alert: FlowAlert) -> some View {
        let pending = store.pendingCalendarFlight(withID: alert.relatedFlightID)

        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "C9B6FF").opacity(0.16))
                    .frame(width: 42, height: 42)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "C9B6FF"))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Flight found in Calendar")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(pendingFlightSummary(for: pending))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.86))

                Text(relativeUpdateText(from: alert.createdAt))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.60))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
                .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color(hex: "9B6CFF").opacity(0.18), lineWidth: 1)
                )
        )
    }

    func pendingFlightSummary(for pending: PendingCalendarFlight?) -> String {
        guard let pending else {
            return "Tap to review it in Search."
        }

        if let route = cleanedText(pending.routeText) {
            return "We found \(pending.flightNumber) · \(route). Tap to review it in Search."
        } else {
            return "We found \(pending.flightNumber) in your calendar. Tap to review it in Search."
        }
    }
}

// MARK: - Standard Alert Cards

private extension AlertsView {

    func standardAlertCard(_ alert: FlowAlert) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor(for: alert).opacity(0.16))
                    .frame(width: 42, height: 42)
                    .scaleEffect(alert.severity == .critical && pulseCritical ? 1.06 : 1.0)
                    .animation(
                        alert.severity == .critical
                        ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                        : .default,
                        value: pulseCritical
                    )

                Image(systemName: iconName(for: alert))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(accentColor(for: alert))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(alert.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(alert.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.86))

                Text(relativeUpdateText(from: alert.createdAt))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.60))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
                .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(borderColor(for: alert), lineWidth: 1)
                )
        )
    }
}

// MARK: - Calendar Flight Sheet

private extension AlertsView {

    func calendarFlightSheet(_ pending: PendingCalendarFlight) -> some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "2A0C5A"),
                    Color(hex: "3B136E"),
                    Color(hex: "14062F")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "C9B6FF"))

                    Text("From Calendar")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(pending.flightNumber)
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(.white)

                    Text(pending.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(2)

                    Text(calendarDetailLine(for: pending))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        if let airport = cleanedText(pending.departureAirportCode) {
                            compactTag(airport, tint: .white.opacity(0.16))
                        }

                        if let route = cleanedText(pending.routeText) {
                            compactTag(route, tint: .white.opacity(0.16))
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )

                HStack(spacing: 10) {
                    Button {
                        selectedCalendarFlight = nil
                    } label: {
                        Text("Not now")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        print("🟣 ALERTS Review tapped")
                        print("🟣 pending.id =", pending.id)
                        print("🟣 pending.flightNumber =", pending.flightNumber)
                        print("🟣 pending.title =", pending.title)
                        print("🟣 pending.routeText =", pending.routeText ?? "nil")

                        store.reviewCalendarFlight = pending

                        print("🟣 store.reviewCalendarFlight set to =", store.reviewCalendarFlight?.flightNumber ?? "nil")
                        print("🟣 store.reviewCalendarFlight id =", store.reviewCalendarFlight?.id ?? "nil")

                        selectedCalendarFlight = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            print("🟣 Navigating to planner with reviewCalendarFlight =", store.reviewCalendarFlight?.flightNumber ?? "nil")
                            selectedTab = .planner
                        }
                    } label: {
                        Text("Review in Search")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "9B6CFF").opacity(0.92))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
    }

    func calendarDetailLine(for pending: PendingCalendarFlight) -> String {
        let dateText = formattedDate(pending.departureDate)

        if let location = cleanedText(pending.location) {
            return "\(dateText) · \(location)"
        }

        return dateText
    }
}

// MARK: - Actions

private extension AlertsView {

    func handleTap(on alert: FlowAlert) {
        switch alert.kind {
        case .calendarFlightDetected:
            if let pending = store.pendingCalendarFlight(withID: alert.relatedFlightID) {
                selectedCalendarFlight = pending
            }

        case .trackedFlight, .leaveNow, .leaveSoon, .onTrack:
            selectedTab = .flight

        default:
            break
        }
    }
}

// MARK: - Helpers

private extension AlertsView {

    func iconName(for alert: FlowAlert) -> String {
        switch alert.severity {
        case .critical:
            return "exclamationmark"
        case .warning:
            return "clock.fill"
        case .info:
            return "bell.fill"
        }
    }

    func accentColor(for alert: FlowAlert) -> Color {
        switch alert.severity {
        case .critical:
            return .red.opacity(0.95)
        case .warning:
            return .orange.opacity(0.95)
        case .info:
            return .white.opacity(0.9)
        }
    }

    func borderColor(for alert: FlowAlert) -> Color {
        switch alert.severity {
        case .critical:
            return Color.red.opacity(0.28)
        case .warning:
            return Color.orange.opacity(0.22)
        case .info:
            return Color.white.opacity(0.10)
        }
    }

    func relativeUpdateText(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 10 {
            return "Updated just now"
        } else if seconds < 60 {
            return "Updated \(seconds)s ago"
        } else if seconds < 3600 {
            return "Updated \(seconds / 60)m ago"
        } else {
            return "Updated \(seconds / 3600)h ago"
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM · HH:mm"
        return formatter.string(from: date)
    }

    func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    func departureAirportCode(from route: String) -> String {
        route.components(separatedBy: "→")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "—"
    }

    func cleanedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func cleanedStatus(_ value: String?) -> String? {
        cleanedText(value)
    }

    func compactTag(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white.opacity(0.92))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tint)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
    }

    func detailMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.60))

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
