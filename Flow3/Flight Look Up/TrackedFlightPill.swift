import SwiftUI

struct TrackedFlightPill: View {

    @ObservedObject var store: LandingStore

    @State private var expanded = false
    @State private var pulse = false
    @State private var isRefreshing = false
    @State private var showingRoutePicker = false

    private let refreshTimer = Timer.publish(every: 120, on: .main, in: .common).autoconnect()

    private var availableRoutes: [SecurityRouteOption] {
        store.availableSecurityRoutes(for: store.selectedAirport)
    }

    var body: some View {
        Group {
            if let flight = store.trackedFlight {
                VStack(alignment: .leading, spacing: 16) {

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            expanded.toggle()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 14) {

                            HStack {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(pulse ? 1.2 : 0.8)
                                        .opacity(pulse ? 0.4 : 1)
                                        .animation(
                                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                                            value: pulse
                                        )

                                    Text("Tracking Flight")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.green.opacity(0.95))
                                }

                                Spacer()

                                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Text("\(flight.flightNumber) • \(flight.route)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

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

                            HStack(spacing: 16) {
                                Image(systemName: "airplane")
                                    .font(.system(size: 16, weight: .semibold))

                                Text(timeString(flight.departureTime))
                                    .font(.system(size: 15, weight: .semibold))

                                Image(systemName: "building.2")
                                    .font(.system(size: 16))

                                Text("T\(flight.terminal)")
                                    .font(.system(size: 15, weight: .semibold))

                                Image(systemName: "suitcase")
                                    .font(.system(size: 16))

                                Text(flight.securityRouteTitle)
                                    .font(.system(size: 15, weight: .semibold))

                                Spacer()
                            }
                            .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .buttonStyle(.plain)

                    if expanded {
                        Divider()
                            .overlay(Color.white.opacity(0.12))

                        VStack(alignment: .leading, spacing: 14) {
                            infoRow("Airline", flight.airline)
                            infoRow("Terminal", flight.terminal.isEmpty ? "—" : flight.terminal)

                            if let gate = flight.gate,
                               !gate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                infoRow("Gate", gate)
                            }

                            infoRow("Departure", timeString(flight.departureTime))
                            infoRow("Leave at", timeString(flight.leaveTime))
                            infoRow("Gate target", timeString(flight.gateTargetTime))

                            Divider()
                                .overlay(Color.white.opacity(0.10))

                            infoRow(
                                "Security route",
                                securityRouteValueText(for: flight)
                            )

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
                }
                .padding(20)
                .background(
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
                )
                .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
                .onAppear {
                    pulse = true
                }
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
                    Button("Auto") {
                        store.setTrackedFlightSecurityRoute(nil)
                    }

                    ForEach(availableRoutes) { route in
                        Button(routePickerTitle(for: route)) {
                            store.setTrackedFlightSecurityRoute(route.id)
                        }
                    }

                    Button("Cancel", role: .cancel) { }
                }
            }
        }
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

    private func routePickerTitle(for route: SecurityRouteOption) -> String {
        let base = route.subtitle.isEmpty
            ? "\(route.title) • \(route.minutes)m"
            : "\(route.title) • \(route.subtitle) • \(route.minutes)m"

        if route.isPreCheckOnly {
            return "\(base) • PreCheck only"
        }

        return base
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
