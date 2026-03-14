import SwiftUI

struct DeparturePlannerSheet: View {

    @ObservedObject var store: LandingStore
    @Environment(\.dismiss) private var dismiss

    @State private var departureTime: Date = Calendar.current.date(
        byAdding: .hour,
        value: 3,
        to: Date()
    ) ?? Date()

    @State private var checkedBags = false
    @State private var isCalculating = false
    @State private var errorText: String?
    @State private var plan: DeparturePlan?

    private let travelTimeService = TravelTimeService()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {

                    plannerIntroCard
                    inputsCard
                    actionButton

                    if let plan {
                        resultCard(plan)
                    }

                    if let errorText, !errorText.isEmpty {
                        Text(errorText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red.opacity(0.95))
                            .padding(.top, 4)
                    }
                }
                .padding(16)
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
            .navigationTitle("Plan Departure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    private var plannerIntroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heathrow departure planner")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text("Flow will calculate when to leave based on live LHR security wait times, driving time from your current location, and a target of being at the gate 60 minutes before departure.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
        }
        .flowGlassCard()
    }

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 16) {

            VStack(alignment: .leading, spacing: 8) {
                Text("Airport")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))

                Text("LHR · London Heathrow")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Departure time")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))

                DatePicker(
                    "",
                    selection: $departureTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .colorScheme(.dark)
            }

            Toggle(isOn: $checkedBags) {
                Text("Checked bags")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .tint(Color(hex: "7B6CFF"))
        }
        .flowGlassCard()
    }

    private var actionButton: some View {
        Button {
            Task {
                await calculate()
            }
        } label: {
            HStack {
                Spacer()

                if isCalculating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Calculate leave time")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()
            }
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isCalculating)
    }

    private func resultCard(_ plan: DeparturePlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Leave at")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.76))

            Text(timeString(plan.recommendedLeaveTime))
                .font(.system(size: 52, weight: .heavy))
                .foregroundColor(.white)
                .monospacedDigit()

            Text("to reach gate by \(timeString(plan.gateTargetTime))")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.78))

            Divider()
                .overlay(Color.white.opacity(0.10))

            VStack(spacing: 10) {
                resultRow("Departure time", timeString(plan.departureTime))
                resultRow("Gate target", timeString(plan.gateTargetTime))
                resultRow("Travel time", "\(plan.travelMinutes)m")
                resultRow("Security wait", "\(plan.securityMinutes)m")
                resultRow("Travel + security", "\(plan.travelMinutes + plan.securityMinutes)m")
                resultRow("Terminal buffer", "\(plan.airportBufferMinutes)m")

                if plan.bagBufferMinutes > 0 {
                    resultRow("Bag drop buffer", "\(plan.bagBufferMinutes)m")
                }
            }

            Text("Based on your current location, live Heathrow security wait times, and a target of reaching the gate 60 minutes before departure.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.68))
                .padding(.top, 2)
        }
        .flowGlassCard()
    }

    private func resultRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.72))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = store.selectedAirport.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    @MainActor
    private func calculate() async {
        errorText = nil
        isCalculating = true
        defer { isCalculating = false }

        do {
            let travelMinutes = try await travelTimeService.drivingMinutesToHeathrow()
            let securityMinutes = max(0, store.overallMinutes(.general) ?? 0)

            plan = DeparturePlanner.makePlan(
                departureTime: departureTime,
                travelMinutes: travelMinutes,
                securityMinutes: securityMinutes,
                checkedBags: checkedBags
            )
        } catch {
            errorText = error.localizedDescription
        }
    }
}
