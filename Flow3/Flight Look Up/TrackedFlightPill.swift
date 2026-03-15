import SwiftUI

struct TrackedFlightPill: View {

    @ObservedObject var store: LandingStore
    @State private var expanded = false
    @State private var pulse = false
    @State private var isRefreshing = false

    private let refreshTimer = Timer.publish(every: 120, on: .main, in: .common).autoconnect()

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

                            Text("\(flight.flightNumber) · \(flight.route)")
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
                            }

                            HStack(spacing: 16) {
                                Label(
                                    timeString(flight.departureTime),
                                    systemImage: "airplane.departure"
                                )
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))

                                Label(
                                    "T\(flight.terminal)",
                                    systemImage: "building.2"
                                )
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if expanded {
                        Divider()
                            .overlay(Color.white.opacity(0.12))

                        VStack(alignment: .leading, spacing: 14) {
                            infoRow("Airline", flight.airline)
                            infoRow("Terminal", flight.terminal)
                            infoRow("Departure", timeString(flight.departureTime))
                            infoRow("Leave at", timeString(flight.leaveTime))
                            infoRow("Gate target", timeString(flight.gateTargetTime))

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
            }
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

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
