import SwiftUI

struct TrackedFlightPill: View {

    @ObservedObject var store: LandingStore

    @State private var savedTrackedFlight: SavedFlightPlan?
    @State private var isExpanded = false
    @State private var isRefreshing = false
    @State private var statusText: String?
    @State private var statusColor: Color = .white.opacity(0.75)

    private let savedFlightStore = SavedFlightStore.shared
    private let travelTimeService = TravelTimeService()
    private let flightLookupService = FlightLookupService()

    private let refreshTimer = Timer.publish(every: 120, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if store.selectedAirport == .lhr, let savedTrackedFlight {
                VStack(alignment: .leading, spacing: 12) {

                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 12) {

                            VStack(alignment: .leading, spacing: 6) {

                                HStack(spacing: 6) {

                                    Text("Tracked Flight")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)

                                    Text("·")

                                    Text("\(savedTrackedFlight.flightNumber)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white.opacity(0.9))

                                    Text("·")

                                    Text("\(savedTrackedFlight.originIATA) → \(savedTrackedFlight.destinationIATA)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.85))
                                }

                                HStack(spacing: 6) {

                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white.opacity(0.85))

                                    Text("Leave at")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.70))

                                    Text(timeString(savedTrackedFlight.leaveTime))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(leaveTimeColor(for: savedTrackedFlight.leaveTimeTrend))
                                        .monospacedDigit()
                                }
                            }
                            Spacer()

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.70))
                        }
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        Divider()
                            .overlay(Color.white.opacity(0.10))

                        VStack(spacing: 10) {
                            infoRow("Flight", savedTrackedFlight.flightNumber)
                            infoRow("Route", "\(savedTrackedFlight.originIATA) → \(savedTrackedFlight.destinationIATA)")
                            infoRow("Airline", savedTrackedFlight.airline)

                            if let terminal = savedTrackedFlight.terminal {
                                infoRow("Terminal", terminal)
                            }

                            infoRow("Departure", flightDateTimeString(savedTrackedFlight.departureTime))
                            infoRow("Leave at", timeString(savedTrackedFlight.leaveTime))
                            infoRow("Gate target", timeString(savedTrackedFlight.gateTargetTime))
                            infoRow("Travel time", "\(savedTrackedFlight.travelMinutes)m")
                            infoRow("Security wait", "\(savedTrackedFlight.securityMinutes)m")
                            infoRow("Terminal buffer", "\(savedTrackedFlight.terminalBufferMinutes)m")

                            if savedTrackedFlight.bagBufferMinutes > 0 {
                                infoRow("Bag drop", "\(savedTrackedFlight.bagBufferMinutes)m")
                            }

                            infoRow("Updated", relativeDateString(savedTrackedFlight.lastUpdated))
                        }

                        if !savedTrackedFlight.lastMonitorMessages.isEmpty {
                            Divider()
                                .overlay(Color.white.opacity(0.10))

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Live updates")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)

                                ForEach(savedTrackedFlight.lastMonitorMessages, id: \.self) { message in
                                    Text("• \(message)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.86))
                                }
                            }
                        }

                        VStack(spacing: 12) {
                            Button {
                                Task {
                                    await refreshTrackedFlight(savedTrackedFlight)
                                }
                            } label: {
                                HStack {
                                    Spacer()

                                    if isRefreshing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Refresh")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.white.opacity(0.10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isRefreshing)

                            Button {
                                stopTracking()
                            } label: {
                                HStack {
                                    Spacer()

                                    Text("Stop tracking")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.red.opacity(0.95))

                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if let statusText, !statusText.isEmpty {
                            Text(statusText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(statusColor)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
            }
        }
        .onAppear {
            loadSavedFlight()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            loadSavedFlight()
        }
        .onReceive(refreshTimer) { _ in
            guard store.selectedAirport == .lhr else { return }
            guard let savedTrackedFlight else { return }
            Task {
                await refreshTrackedFlight(savedTrackedFlight)
            }
        }
    }

    private func loadSavedFlight() {
        savedTrackedFlight = savedFlightStore.loadLHRTrackedFlight()
    }

    private func stopTracking() {
        savedFlightStore.clearLHRTrackedFlight()
        savedTrackedFlight = nil
        statusText = "Stopped tracking."
        statusColor = .green.opacity(0.95)
    }

    @MainActor
    private func refreshTrackedFlight(_ saved: SavedFlightPlan) async {
        isRefreshing = true
        statusText = nil
        defer { isRefreshing = false }

        do {
            await store.refresh()

            let latestFlight = try await flightLookupService.lookupFlight(
                flightNumber: saved.flightNumber,
                date: saved.departureTime
            )

            let travelMinutes = try await travelTimeService.drivingMinutesToHeathrow()
            let securityMinutes = max(0, store.overallMinutes(.general) ?? 0)

            let newPlan = DeparturePlanner.makePlan(
                departureTime: latestFlight.departureTime,
                travelMinutes: travelMinutes,
                securityMinutes: securityMinutes,
                checkedBags: saved.checkedBags
            )

            let trend: TrackedLeaveTimeTrend
            if newPlan.recommendedLeaveTime < saved.leaveTime {
                trend = .earlier
            } else if newPlan.recommendedLeaveTime > saved.leaveTime {
                trend = .later
            } else {
                trend = .unchanged
            }

            let updated = SavedFlightPlan(
                flightNumber: latestFlight.flightNumber,
                airline: latestFlight.airline,
                originIATA: latestFlight.originIATA,
                destinationIATA: latestFlight.destinationIATA,
                terminal: latestFlight.terminal,
                departureTime: latestFlight.departureTime,
                checkedBags: saved.checkedBags,
                leaveTime: newPlan.recommendedLeaveTime,
                gateTargetTime: newPlan.gateTargetTime,
                travelMinutes: newPlan.travelMinutes,
                securityMinutes: newPlan.securityMinutes,
                terminalBufferMinutes: newPlan.airportBufferMinutes,
                bagBufferMinutes: newPlan.bagBufferMinutes,
                lastUpdated: Date(),
                lastMonitorMessages: [],
                leaveTimeTrend: trend
            )

            let monitorResult = DepartureMonitor.compare(old: saved, new: updated)

            let finalSaved = SavedFlightPlan(
                flightNumber: updated.flightNumber,
                airline: updated.airline,
                originIATA: updated.originIATA,
                destinationIATA: updated.destinationIATA,
                terminal: updated.terminal,
                departureTime: updated.departureTime,
                checkedBags: updated.checkedBags,
                leaveTime: updated.leaveTime,
                gateTargetTime: updated.gateTargetTime,
                travelMinutes: updated.travelMinutes,
                securityMinutes: updated.securityMinutes,
                terminalBufferMinutes: updated.terminalBufferMinutes,
                bagBufferMinutes: updated.bagBufferMinutes,
                lastUpdated: updated.lastUpdated,
                lastMonitorMessages: monitorResult.messages,
                leaveTimeTrend: trend
            )

            savedFlightStore.saveLHRTrackedFlight(finalSaved)
            savedTrackedFlight = finalSaved

            if monitorResult.messages.isEmpty {
                statusText = "No meaningful change detected."
                statusColor = .white.opacity(0.75)
            } else {
                statusText = "Tracked flight updated."
                statusColor = .green.opacity(0.95)
            }
        } catch {
            statusText = error.localizedDescription
            statusColor = .red.opacity(0.95)
        }
    }

    private func leaveTimeColor(for trend: TrackedLeaveTimeTrend) -> Color {
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
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.72))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = store.selectedAirport.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func flightDateTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = store.selectedAirport.timeZone
        formatter.dateFormat = "dd MMM yyyy · HH:mm"
        return formatter.string(from: date)
    }

    private func relativeDateString(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))

        if seconds < 60 { return "\(seconds)s ago" }

        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }

        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }

        let days = hours / 24
        return "\(days)d ago"
    }
}
