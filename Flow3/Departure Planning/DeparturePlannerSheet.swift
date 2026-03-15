import SwiftUI

struct DeparturePlannerSheet: View {

    @ObservedObject var store: LandingStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFlightFieldFocused: Bool

    @State private var departureTime: Date = Calendar.current.date(
        byAdding: .hour,
        value: 3,
        to: Date()
    ) ?? Date()

    @State private var checkedBags = false
    @State private var isCalculating = false
    @State private var isLookingUpFlight = false

    @State private var errorText: String?
    @State private var plan: DeparturePlan?

    @State private var useFlightNumber = false
    @State private var flightNumber = ""
    @State private var flightDate = Date()
    @State private var flightLookupResult: FlightLookupResult?

    private let travelTimeService = TravelTimeService()
    private let flightLookupService = FlightLookupService()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {

                    plannerIntroCard

                    if store.selectedAirport == .lhr {
                        plannerModePicker
                    }

                    if useFlightNumber {
                        flightLookupCard
                    } else {
                        inputsCard
                    }

                    if let flight = flightLookupResult, useFlightNumber {
                        flightFoundCard(flight)
                    }

                    bagToggleCard

                    actionButton

                    if let plan {
                        resultCard(plan)
                    }

                    if canTrackFlight {
                        trackFlightButton
                    }

                    if let errorText, !errorText.isEmpty {
                        Text(errorText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red.opacity(0.95))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded {
                    isFlightFieldFocused = false
                    hideKeyboard()
                }
            )
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
                        isFlightFieldFocused = false
                        hideKeyboard()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done") {
                        isFlightFieldFocused = false
                        hideKeyboard()
                    }
                    .foregroundColor(.white)
                }
            }
            .onChange(of: useFlightNumber) { _ in
                errorText = nil
                plan = nil
                flightLookupResult = nil
                isFlightFieldFocused = false
                hideKeyboard()
            }
        }
    }

    private var canTrackFlight: Bool {
        store.selectedAirport == .lhr &&
        useFlightNumber &&
        flightLookupResult != nil &&
        plan != nil
    }

    private var plannerIntroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heathrow departure planner")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text("Flow calculates when to leave based on live Heathrow security wait times and travel time from your location.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
        }
        .flowGlassCard()
    }

    private var plannerModePicker: some View {
        HStack(spacing: 8) {

            modeButton(title: "Manual", selected: !useFlightNumber) {
                useFlightNumber = false
            }

            modeButton(title: "Flight Number", selected: useFlightNumber) {
                useFlightNumber = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.10))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func modeButton(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(selected ? Color.white.opacity(0.14) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Airport")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.72))

            Text("LHR · London Heathrow")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Text("Departure")
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
        .flowGlassCard()
    }

    private var flightLookupCard: some View {
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
                Text("Flight number")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))

                TextField("e.g. BA216", text: $flightNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .focused($isFlightFieldFocused)
                    .onSubmit {
                        isFlightFieldFocused = false
                        hideKeyboard()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Flight date")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))

                DatePicker(
                    "",
                    selection: $flightDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .colorScheme(.dark)
            }

            Button {
                isFlightFieldFocused = false
                hideKeyboard()

                Task {
                    await lookupFlight()
                }
            } label: {
                HStack {
                    Spacer()

                    if isLookingUpFlight {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Find flight")
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
            .disabled(isLookingUpFlight || flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .flowGlassCard()
    }

    private func flightFoundCard(_ flight: FlightLookupResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Flight found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            infoRow("Flight", flight.flightNumber)
            infoRow("Route", "\(flight.originIATA) → \(flight.destinationIATA)")
            infoRow("Airline", flight.airline)

            if let terminal = flight.terminal {
                infoRow("Terminal", terminal)
            }

            infoRow("Departure", flightDateTimeString(flight.departureTime))
        }
        .flowGlassCard()
    }

    private var bagToggleCard: some View {
        Toggle(isOn: $checkedBags) {
            Text("Checked bags")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
        .tint(Color(hex: "7B6CFF"))
        .flowGlassCard()
    }

    private var actionButton: some View {
        Button {
            isFlightFieldFocused = false
            hideKeyboard()

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
        .disabled(
            isCalculating ||
            isLookingUpFlight ||
            (useFlightNumber && flightLookupResult == nil)
        )
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
                resultRow("Journey time", "\(plan.travelMinutes)m")
                resultRow("Security wait", "\(plan.securityMinutes)m")
                resultRow("Airport buffer", "\(plan.airportBufferMinutes)m")

                if plan.bagBufferMinutes > 0 {
                    resultRow("Bag drop buffer", "\(plan.bagBufferMinutes)m")
                }

                let totalBeforeAirport =
                    plan.travelMinutes +
                    plan.securityMinutes +
                    plan.airportBufferMinutes +
                    plan.bagBufferMinutes

                resultRow("Total pre-airport time", "\(totalBeforeAirport)m")
            }
        }
        .flowGlassCard()
    }

    private var trackFlightButton: some View {
        Button {
            trackThisFlight()
        } label: {
            HStack {
                Spacer()

                Text("Track This Flight")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "9B6CFF").opacity(0.30))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func trackThisFlight() {
        errorText = nil

        guard let flight = flightLookupResult, let plan else {
            errorText = "Look up a flight and calculate leave time first."
            return
        }

        let tracked = TrackedFlight(
            flightNumber: flight.flightNumber,
            route: "\(flight.originIATA) → \(flight.destinationIATA)",
            airline: flight.airline,
            terminal: flight.terminal ?? "",
            departureTime: flight.departureTime,
            leaveTime: plan.recommendedLeaveTime,
            gateTargetTime: plan.gateTargetTime,
            travelMinutes: plan.travelMinutes,
            securityMinutes: plan.securityMinutes,
            airportBufferMinutes: plan.airportBufferMinutes,
            bagBufferMinutes: plan.bagBufferMinutes,
            leaveTimeTrend: .unchanged
        )

        store.trackFlight(tracked)
        dismiss()
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

    private func lookupFlight() async {
        errorText = nil
        plan = nil
        flightLookupResult = nil
        isLookingUpFlight = true
        defer { isLookingUpFlight = false }

        do {
            let result = try await flightLookupService.lookupFlight(
                flightNumber: flightNumber
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased(),
                date: flightDate
            )

            flightLookupResult = result
            departureTime = result.departureTime
        } catch {
            errorText = error.localizedDescription
        }
    }

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
