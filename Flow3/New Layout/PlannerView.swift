import SwiftUI

struct PlannerPlaceholderView: View {

    @ObservedObject var store: LandingStore
    @Binding var selectedTab: FlowTab
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

    @State private var useFlightNumber = true
    @State private var flightNumber = ""
    @State private var flightDate = Date()
    @State private var flightLookupResult: FlightLookupResult?

    @State private var useManualTravelTime = false
    @State private var manualTravelMinutes = 20

    private let travelTimeService = TravelTimeService()
    private let flightLookupService = LiveFlightService()

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
                    plannerHeaderCard
                    plannerModePicker

                    if useFlightNumber {
                        flightLookupCard
                    } else {
                        manualPlannerCard
                    }

                    if let flight = flightLookupResult, useFlightNumber {
                        flightFoundCard(flight)
                    }

                    travelSetupCard
                    actionButton

                    if let plan {
                        leaveTimeHero(plan)
                        breakdownCard(plan)
                        trackFlightButton
                    }

                    if let errorText, !errorText.isEmpty {
                        Text(errorText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red.opacity(0.95))
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Planner")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            isFlightFieldFocused = false
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    isFlightFieldFocused = false
                }
                .foregroundColor(.white)
            }
        }
        .onChange(of: useFlightNumber) { _ in
            errorText = nil
            plan = nil
            flightLookupResult = nil
            isFlightFieldFocused = false
        }
        .onAppear {
            resetPlannerForSelectedAirport()
        }
        .onChange(of: store.selectedAirport) { _ in
            resetPlannerForSelectedAirport()
        }
    }
}

// MARK: - Header

private extension PlannerPlaceholderView {

    var airportDisplayLine: String {
        "\(store.selectedAirport.rawValue) · \(store.selectedAirport.displayName)"
    }

    var plannerHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Smart departure planning")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("Calculate when to leave using your flight, live airport conditions, and travel time.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.78))

            HStack(spacing: 8) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Text(airportDisplayLine)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .flowGlassCard()
    }

    var plannerModePicker: some View {
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

    func modeButton(
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
}

// MARK: - Input Cards

private extension PlannerPlaceholderView {

    var flightLookupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            inputTitle("Airport")
            valueLine(airportDisplayLine)

            VStack(alignment: .leading, spacing: 8) {
                inputTitle("Flight number")

                TextField("e.g. BA216", text: $flightNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .focused($isFlightFieldFocused)
                    .onSubmit {
                        isFlightFieldFocused = false
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
                inputTitle("Flight date")

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
            .disabled(
                isLookingUpFlight ||
                flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .flowGlassCard()
    }

    var manualPlannerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            inputTitle("Airport")
            valueLine(airportDisplayLine)

            VStack(alignment: .leading, spacing: 8) {
                inputTitle("Departure")

                DatePicker(
                    "",
                    selection: $departureTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .colorScheme(.dark)
            }
        }
        .flowGlassCard()
    }

    func flightFoundCard(_ flight: FlightLookupResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flight found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            infoRow("Flight", flight.flightNumber)
            infoRow("Route", cleanedRoute(origin: flight.originIATA, destination: flight.destinationIATA))
            infoRow("Airline", flight.airline)

            if let terminal = flight.terminal, !terminal.isEmpty {
                infoRow("Terminal", terminal)
            }

            if let gate = flight.gate, !gate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                infoRow("Gate", gate)
            }

            infoRow("Departure", flightDateTimeString(flight.departureTime))
        }
        .flowGlassCard()
    }

    var travelSetupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Travel setup")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Toggle(isOn: $checkedBags) {
                Text("Checked bags")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .tint(Color(hex: "7B6CFF"))

            Toggle(isOn: $useManualTravelTime) {
                Text("Enter travel time manually")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .tint(Color(hex: "7B6CFF"))

            if useManualTravelTime {
                Stepper(value: $manualTravelMinutes, in: 5...180, step: 5) {
                    HStack {
                        Text("Travel time")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))

                        Spacer()

                        Text("\(manualTravelMinutes) min")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                }
                .tint(.white)
            } else {
                Text("Flow will use live travel time from your location.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.68))
            }
        }
        .flowGlassCard()
    }

    var actionButton: some View {
        Button {
            isFlightFieldFocused = false

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
            .padding(.vertical, 15)
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
}

// MARK: - Result

private extension PlannerPlaceholderView {

    func leaveTimeHero(_ plan: DeparturePlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Leave at")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.72))

            Text(timeString(plan.recommendedLeaveTime))
                .font(.system(size: 60, weight: .heavy))
                .foregroundColor(.white)
                .monospacedDigit()

            Text(countdownText(for: plan.recommendedLeaveTime))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(countdownColor(for: plan.recommendedLeaveTime))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.purple.opacity(0.35), radius: 20, x: 0, y: 10)
        )
    }

    func breakdownCard(_ plan: DeparturePlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Breakdown")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            resultRow("Travel time", "\(plan.travelMinutes)m")
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
            resultRow("Gate target", timeString(plan.gateTargetTime))
        }
        .flowGlassCard()
    }

    var trackFlightButton: some View {
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
}

// MARK: - Logic

private extension PlannerPlaceholderView {

    func trackThisFlight() {
        errorText = nil

        guard let flight = flightLookupResult, let plan else {
            errorText = "Look up a flight and calculate leave time first."
            return
        }

        let securitySelection = store.plannerSecuritySelection(
            for: store.selectedAirport,
            flightTerminal: flight.terminal,
            preferredRouteID: nil
        )

        let tracked = TrackedFlight(
            flightNumber: flight.flightNumber,
            route: "\(flight.originIATA) → \(flight.destinationIATA)",
            airline: flight.airline,
            terminal: flight.terminal ?? "",
            gate: flight.gate,
            departureTime: flight.departureTime,
            leaveTime: plan.recommendedLeaveTime,
            gateTargetTime: plan.gateTargetTime,
            travelMinutes: plan.travelMinutes,
            securityMinutes: plan.securityMinutes,
            airportBufferMinutes: plan.airportBufferMinutes,
            bagBufferMinutes: plan.bagBufferMinutes,
            leaveTimeTrend: .unchanged,
            securityRouteMode: securitySelection.mode,
            securityRouteID: securitySelection.option.id,
            securityRouteTitle: securitySelection.option.title,
            securityRouteSubtitle: securitySelection.option.subtitle,
            securityRouteDetail: securitySelection.option.detail,
            securityRouteIsPreCheckOnly: securitySelection.option.isPreCheckOnly
        )

        // ✅ Save flight
        store.trackFlight(tracked)

        // ✅ Navigate to Flight tab
        selectedTab = .flight
    }
    
    func resetPlannerForSelectedAirport() {
        errorText = nil
        plan = nil
        flightLookupResult = nil
        flightNumber = ""
        checkedBags = false
        useManualTravelTime = false
        manualTravelMinutes = 20
        departureTime = Calendar.current.date(
            byAdding: .hour,
            value: 3,
            to: Date()
        ) ?? Date()
        flightDate = Date()
        useFlightNumber = true
    }

    func lookupFlight() async {
        errorText = nil
        plan = nil
        flightLookupResult = nil
        isLookingUpFlight = true
        defer { isLookingUpFlight = false }

        do {
            let trimmedFlightNumber = flightNumber
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()

            let result = try await flightLookupService.lookupFlight(
                flightNumber: trimmedFlightNumber,
                date: flightDate,
                airportIATA: store.selectedAirport.rawValue
            )

            flightLookupResult = result
            departureTime = result.departureTime

        } catch {
            errorText = error.localizedDescription
        }
    }

    func calculate() async {
        errorText = nil
        isCalculating = true
        defer { isCalculating = false }

        do {
            let travelMinutes: Int

            if useManualTravelTime {
                travelMinutes = manualTravelMinutes
            } else {
                travelMinutes = try await travelTimeService.drivingMinutes(
                    to: store.selectedAirport
                )
            }

            let securitySelection = store.plannerSecuritySelection(
                for: store.selectedAirport,
                flightTerminal: flightLookupResult?.terminal,
                preferredRouteID: nil
            )

            plan = DeparturePlanner.makePlan(
                departureTime: departureTime,
                travelMinutes: travelMinutes,
                securityMinutes: max(0, securitySelection.option.minutes),
                checkedBags: checkedBags
            )

        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Helpers

private extension PlannerPlaceholderView {

    func inputTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white.opacity(0.72))
    }

    func valueLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
    }

    func infoRow(_ title: String, _ value: String) -> some View {
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

    func resultRow(_ title: String, _ value: String) -> some View {
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

    func cleanedRoute(origin: String, destination: String) -> String {
        let safeDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || destination == "UNK"
            ? "—"
            : destination

        return "\(origin) → \(safeDestination)"
    }

    func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = store.selectedAirport.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    func flightDateTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = store.selectedAirport.timeZone
        formatter.dateFormat = "dd MMM yyyy · HH:mm"
        return formatter.string(from: date)
    }

    func countdownText(for leaveTime: Date) -> String {
        let seconds = Int(leaveTime.timeIntervalSinceNow)

        if seconds <= 0 {
            return "Leave now"
        }

        let minutes = seconds / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        return "Leaving in \(hours)h \(remainingMinutes)m"
    }

    func countdownColor(for leaveTime: Date) -> Color {
        let seconds = leaveTime.timeIntervalSinceNow

        if seconds <= 0 {
            return .red
        } else if seconds < 1800 {
            return .orange
        } else {
            return .green
        }
    }
}
