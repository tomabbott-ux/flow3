import SwiftUI

struct AlertsView: View {
    @ObservedObject var store: LandingStore
    @Binding var selectedTab: FlowTab

    @State private var pulseCritical = false

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
                VStack(alignment: .leading, spacing: 16) {
                    headerCard

                    if store.alerts.isEmpty {
                        emptyStateCard
                    } else {
                        ForEach(store.alerts) { alert in
                            Button {
                                handleTap(for: alert)
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
        .onChange(of: store.selectedAirport) { _ in
            store.rebuildAlerts()
        }
        .onChange(of: store.trackedFlight?.id) { _ in
            store.rebuildAlerts()
        }
        .onChange(of: store.lastUpdated) { _ in
            store.rebuildAlerts()
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
                .foregroundColor(.white.opacity(0.76))
        }
        .flowGlassCard()
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 40, height: 40)

                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                }

                Text("No active alerts")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("You’re all caught up. Flow will surface meaningful airport and flight changes here.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
        }
        .flowGlassCard()
    }

    private func alertCard(_ alert: FlowAlert) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accentColor(for: alert).opacity(alert.severity == .critical ? 0.24 : 0.18))
                        .frame(width: 30, height: 30)
                        .scaleEffect(alert.severity == .critical ? (pulseCritical ? 1.06 : 0.96) : 1.0)
                        .opacity(alert.severity == .critical ? (pulseCritical ? 1.0 : 0.82) : 1.0)
                        .animation(
                            alert.severity == .critical
                            ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                            : .default,
                            value: pulseCritical
                        )

                    Image(systemName: iconName(for: alert))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(accentColor(for: alert))
                }

                Text(alert.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if shouldShowAirportCode(for: alert) {
                    Text(alert.airportCode)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.28))
            }

            Text(alert.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.82))

            Text(relativeTimeString(from: alert.createdAt))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.50))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(borderColor(for: alert), lineWidth: 1)
                )
        )
    }

    private func handleTap(for alert: FlowAlert) {
        switch alert.kind {
        case .leaveNow, .leaveSoon, .trackedFlight, .onTrack:
            selectedTab = .flight

        case .securityHigh, .securityRising, .checkpointClosed, .weatherImpact:
            selectedTab = .explore
        }
    }

    private func iconName(for alert: FlowAlert) -> String {
        switch alert.kind {
        case .leaveNow:
            return "exclamationmark"
        case .leaveSoon:
            return "clock.fill"
        case .onTrack:
            return "checkmark"
        case .securityHigh:
            return "person.2.fill"
        case .securityRising:
            return "arrow.up.right"
        case .checkpointClosed:
            return "xmark"
        case .weatherImpact:
            return "cloud.rain.fill"
        case .trackedFlight:
            return "airplane"
        }
    }

    private func accentColor(for alert: FlowAlert) -> Color {
        switch alert.severity {
        case .critical:
            return .red.opacity(0.95)
        case .warning:
            return .orange.opacity(0.95)
        case .info:
            return Color.white.opacity(0.90)
        }
    }

    private func borderColor(for alert: FlowAlert) -> Color {
        switch alert.severity {
        case .critical:
            return .red.opacity(pulseCritical ? 0.34 : 0.18)
        case .warning:
            return .orange.opacity(0.22)
        case .info:
            return .white.opacity(0.10)
        }
    }

    private func shouldShowAirportCode(for alert: FlowAlert) -> Bool {
        alert.airportCode.uppercased() != store.selectedAirport.rawValue.uppercased()
    }

    private func relativeTimeString(from date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        let minutes = seconds / 60

        if minutes <= 0 {
            return "Updated just now"
        } else if minutes == 1 {
            return "Updated 1 minute ago"
        } else if minutes < 60 {
            return "Updated \(minutes) minutes ago"
        } else {
            let hours = minutes / 60
            return hours == 1 ? "Updated 1 hour ago" : "Updated \(hours) hours ago"
        }
    }
}
