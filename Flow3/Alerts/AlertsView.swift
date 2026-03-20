import SwiftUI

struct AlertsView: View {
    @ObservedObject var store: LandingStore
    @State private var pulseCritical = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                headerCard

                if store.alerts.isEmpty {
                    emptyStateCard
                } else {
                    ForEach(store.alerts) { alert in
                        alertCard(alert)
                    }
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
        .onChange(of: store.trackedFlight?.flightNumber) { _ in
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

    private func iconName(for alert: FlowAlert) -> String {
        switch alert.severity {
        case .critical:
            return "exclamationmark"
        case .warning:
            return "clock.fill"
        case .info:
            return "bell.fill"
        }
    }

    private func accentColor(for alert: FlowAlert) -> Color {
        switch alert.severity {
        case .critical:
            return .red.opacity(0.95)
        case .warning:
            return .orange.opacity(0.95)
        case .info:
            return .white.opacity(0.9)
        }
    }

    private func borderColor(for alert: FlowAlert) -> Color {
        switch alert.severity {
        case .critical:
            return Color.red.opacity(0.28)
        case .warning:
            return Color.orange.opacity(0.22)
        case .info:
            return Color.white.opacity(0.10)
        }
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
}
