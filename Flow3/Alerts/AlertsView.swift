import SwiftUI

struct AlertsView: View {
    @ObservedObject var store: LandingStore
    @Binding var selectedTab: FlowRootView.FlowTab

    @State private var pulseCritical = false
    @State private var selectedCalendarFlight: PendingCalendarFlight?

    var body: some View {
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

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard

                    if store.alerts.isEmpty {
                        emptyStateCard
                    } else {
                        ForEach(store.alerts) { alert in
                            Button {
                                handleTap(on: alert)
                            } label: {
                                alertCard(alert)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            store.rebuildAlerts()
        }
        .onAppear {
            pulseCritical = true
        }
        .onChange(of: store.selectedAirport) { _, _ in
            store.rebuildAlerts()
        }
        .onChange(of: store.trackedFlight?.flightNumber) { _, _ in
            store.rebuildAlerts()
        }
        .onChange(of: store.lastUpdated) { _, _ in
            store.rebuildAlerts()
        }
        .sheet(item: $selectedCalendarFlight) { pending in
            compactCalendarFlightSheet(pending)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .animation(.easeInOut(duration: 0.25), value: store.alerts)
    }
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flow alerts")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text("A calm, useful summary of the updates that matter most.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
        }
        .flowGlassCard()
    }

    private var emptyStateCard: some View {
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

    private func alertCard(_ alert: FlowAlert) -> some View {
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
                HStack(alignment: .center, spacing: 8) {
                    Text(alert.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    if alert.kind == .trackedFlight {
                        trackingBadge
                    }

                    Spacer(minLength: 0)
                }

                Text(alert.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.86))

                Text(relativeUpdateText(from: alert.createdAt))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.60))
            }

            if alert.kind == .calendarFlightDetected || isNavigationAlert(alert) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
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

    private var trackingBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)

            Text("TRACKING")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func compactCalendarFlightSheet(_ pending: PendingCalendarFlight) -> some View {
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
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "C9B6FF"))

                    Text("From Calendar")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.72))

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(pending.flightNumber)
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(compactRouteText(for: pending))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.90))
                        .lineLimit(2)

                    Text(compactMetaText(for: pending))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    if let airport = pending.departureAirportCode, !airport.isEmpty {
                        compactTag(text: airport)
                    }

                    if let terminal = terminalText(from: pending), !terminal.isEmpty {
                        compactTag(text: terminal)
                    }
                }

                Spacer(minLength: 0)

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
                        selectedCalendarFlight = nil
                        selectedTab = .planner
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
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 18)
        }
    }

    private func compactTag(text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white.opacity(0.88))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
    }

    private func iconName(for alert: FlowAlert) -> String {
        switch alert.kind {
        case .calendarFlightDetected:
            return "calendar.badge.clock"
        case .trackedFlight:
            return "airplane"
        default:
            switch alert.severity {
            case .critical:
                return "exclamationmark"
            case .warning:
                return "clock.fill"
            case .info:
                return "bell.fill"
            }
        }
    }

    private func accentColor(for alert: FlowAlert) -> Color {
        switch alert.kind {
        case .calendarFlightDetected:
            return Color(hex: "C9B6FF")
        case .trackedFlight:
            return .green
        default:
            switch alert.severity {
            case .critical:
                return .red.opacity(0.95)
            case .warning:
                return .orange.opacity(0.95)
            case .info:
                return .white.opacity(0.9)
            }
        }
    }

    private func handleTap(on alert: FlowAlert) {
        switch alert.kind {
        case .calendarFlightDetected:
            if let pending = store.pendingCalendarFlight {
                selectedCalendarFlight = pending
            }

        case .trackedFlight, .leaveNow, .leaveSoon, .onTrack:
            selectedTab = .flight

        default:
            break
        }
    }

    private func isNavigationAlert(_ alert: FlowAlert) -> Bool {
        switch alert.kind {
        case .trackedFlight, .leaveNow, .leaveSoon, .onTrack:
            return true
        default:
            return false
        }
    }

    private func borderColor(for alert: FlowAlert) -> Color {
        switch alert.kind {
        case .calendarFlightDetected:
            return Color(hex: "9B6CFF").opacity(0.28)
        case .trackedFlight:
            return .green.opacity(0.24)
        default:
            switch alert.severity {
            case .critical:
                return Color.red.opacity(0.28)
            case .warning:
                return Color.orange.opacity(0.22)
            case .info:
                return Color.white.opacity(0.10)
            }
        }
    }

    private func compactRouteText(for pending: PendingCalendarFlight) -> String {
        if let route = pending.routeText, !route.isEmpty {
            return route
        }

        let cleanedTitle = pending.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedTitle.caseInsensitiveCompare(pending.flightNumber) != .orderedSame {
            return cleanedTitle
        }

        return "Upcoming flight"
    }

    private func compactMetaText(for pending: PendingCalendarFlight) -> String {
        let dateText = formattedDate(pending.departureDate)

        if let location = pending.location, !location.isEmpty {
            return "\(dateText) · \(location)"
        }

        return dateText
    }

    private func terminalText(from pending: PendingCalendarFlight) -> String? {
        let candidates = [
            pending.location,
            pending.notes,
            pending.title
        ]
        .compactMap { $0 }

        for text in candidates {
            let upper = text.uppercased()

            if let range = upper.range(of: "TERMINAL ") {
                let suffix = upper[range.upperBound...]
                let terminal = suffix.prefix { $0.isNumber || $0.isLetter }
                if !terminal.isEmpty {
                    return "Terminal \(terminal)"
                }
            }

            if let range = upper.range(of: "T") {
                let suffix = upper[range.upperBound...]
                let terminal = suffix.prefix { $0.isNumber }
                if !terminal.isEmpty {
                    return "Terminal \(terminal)"
                }
            }
        }

        return nil
    }

    private func relativeUpdateText(from date: Date) -> String {
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

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM · HH:mm"
        return formatter.string(from: date)
    }
}
