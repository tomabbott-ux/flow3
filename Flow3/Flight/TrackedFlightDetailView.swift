import SwiftUI

struct TrackedFlightDetailView: View {

    let flight: TrackedFlight
    let airport: FlowAirport

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

            ScrollView {

                VStack(alignment: .leading, spacing: 20) {

                    heroSection
                    flightInfo
                    breakdownSection

                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .navigationTitle("Tracking")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text("Leave at")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Text(timeString(flight.leaveTime))
                .font(.system(size: 56, weight: .heavy))
                .foregroundColor(.white)
                .monospacedDigit()

            Text(countdownText())
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.green)
        }
        .flowGlassCard()
    }

    private var flightInfo: some View {
        VStack(alignment: .leading, spacing: 12) {

            infoRow("Flight", flight.flightNumber)
            infoRow("Route", flight.route)
            infoRow("Terminal", displayTerminal(flight.terminal))
            infoRow("Gate", displayGate(flight.gate))
            infoRow("Departure", timeString(flight.departureTime))

        }
        .flowGlassCard()
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Breakdown")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            infoRow("Travel time", "\(flight.travelMinutes)m")
            infoRow("Security wait", "\(flight.securityMinutes)m")
            infoRow("Airport buffer", "\(flight.airportBufferMinutes)m")

            if flight.bagBufferMinutes > 0 {
                infoRow("Bag buffer", "\(flight.bagBufferMinutes)m")
            }
        }
        .flowGlassCard()
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(value)
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
    }

    private func displayTerminal(_ terminal: String) -> String {
        AirportTerminalFormatter.displayName(
            for: airport,
            rawTerminal: terminal
        )
    }

    private func displayGate(_ gate: String?) -> String {
        let trimmed = gate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "TBD" : trimmed
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = airport.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func countdownText() -> String {
        let seconds = Int(flight.leaveTime.timeIntervalSinceNow)

        if seconds <= 0 {
            return "Leave now"
        }

        let minutes = seconds / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "Leaving in \(hours)h \(remainingMinutes)m"
        } else {
            return "Leaving in \(remainingMinutes)m"
        }
    }
}
