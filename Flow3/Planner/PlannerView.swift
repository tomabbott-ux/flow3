import SwiftUI

struct PlannerView: View {

    @ObservedObject var store: LandingStore
    @Binding var selectedTab: FlowRootView.FlowTab
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

    @State private var autoLookupTask: Task<Void, Never>?
    @State private var lastLookupSignature: String?

    private let travelTimeService = TravelTimeService()
    private let flightLookupService = LiveFlightService()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {

                plannerIntroCard
                plannerModePicker

                if useFlightNumber {
                    flightLookupCard
                } else {
                    inputsCard
                }

                if let flight = flightLookupResult, useFlightNumber {
                    flightFoundCard(flight)
                }

                bagToggleCard
                travelTimeCard
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
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    isFlightFieldFocused = false
                }
                .foregroundColor(.white)
            }
        }
        .onAppear {
            resetPlanner()
        }
        .onChange(of: useFlightNumber) {
            autoLookupTask?.cancel()
            lastLookupSignature = nil
            errorText = nil
            plan = nil
            flightLookupResult = nil
            isFlightFieldFocused = false
        }
        .onChange(of: flightNumber) {
            scheduleAutoLookupIfNeeded()
        }
        .onChange(of: flightDate) {
            scheduleAutoLookupIfNeeded()
        }
        .onDisappear {
            autoLookupTask?.cancel()
        }
    }
}

// MARK: - UI

private extension PlannerView {

    var canTrackFlight: Bool {
        useFlightNumber &&
        flightLookupResult != nil &&
        plan != nil &&
        currentFlightIsSupported
    }

    var airportTitle: String {
        "Flight search"
    }

    var airportDescription: String {
        "Search by flight number and Flow will find the airport automatically, or build a manual airport timing plan."
    }

    var airportDisplayLine: String {
        "\(store.selectedAirport.rawValue) · \(store.selectedAirport.displayName)"
    }

    var currentFlightIsSupported: Bool {
        guard let flightLookupResult else { return true }
        return flowAirport(from: flightLookupResult.originIATA) != nil
    }

    var plannerIntroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(airportTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text(airportDescription)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
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

    var inputsCard: some View {
        VStack(alignment: .leading, spacing: 16) {

            inputTitle("Airport")
            valueLine(airportDisplayLine)

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
        .flowGlassCard()
    }

    var flightLookupCard: some View {
        VStack(alignment: .leading, spacing: 16) {

            VStack(alignment: .leading, spacing: 8) {
                inputTitle("Flight number")

                TextField("e.g. BA216", text: $flightNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .submitLabel(.search)
                    .focused($isFlightFieldFocused)
                    .onSubmit {
                        isFlightFieldFocused = false
                        Task {
                            await lookupFlight(force: true)
                        }
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

            if let flightLookupResult {
                VStack(alignment: .leading, spacing: 8) {
                    inputTitle("Departure airport")
                    valueLine(displayAirportLine(for: flightLookupResult.originIATA))
                }
            }

            Button {
                isFlightFieldFocused = false
                Task {
                    await lookupFlight(force: true)
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
                normalizedFlightNumber.isEmpty
            )
        }
        .flowGlassCard()
    }

    func flightFoundCard(_ flight: FlightLookupResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Flight found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            infoRow("Flight", flight.flightNumber)
            infoRow("Departure airport", displayAirportLine(for: flight.originIATA))
            infoRow("Route", cleanedRoute("\(flight.originIATA) → \(flight.destinationIATA)"))
            infoRow("Airline", flight.airline)

            if let terminal = flight.terminal,
               !terminal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                infoRow("Terminal", terminal)
            }

            if let gate = flight.gate,
               !gate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                infoRow("Gate", gate)
            } else {
                infoRow("Gate", "TBD")
            }

            if let status = flight.status,
               !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                infoRow("Status", status)
            }

            infoRow("Departure", flightDateTimeString(flight.departureTime))

            if !currentFlightIsSupported {
                Text("Flow found this flight, but live airport support for \(flight.originIATA) is not available yet. You can still review the flight details here.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .flowGlassCard()
    }

    var bagToggleCard: some View {
        Toggle(isOn: $checkedBags) {
            Text("Checked bags")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
        .tint(Color(hex: "7B6CFF"))
        .flowGlassCard()
    }

    var travelTimeCard: some View {
        VStack(alignment: .leading, spacing: 14) {

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

    func resultCard(_ plan: DeparturePlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Leave at")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.76))

            Text(timeString(plan.recommendedLeaveTime))
                .font(.system(size: 52, weight: .heavy))
                .foregroundColor(countdownColor(for: plan.recommendedLeaveTime))
                .monospacedDigit()

            Text(countdownText(for: plan.recommendedLeaveTime))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(countdownColor(for: plan.recommendedLeaveTime))

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

    var trackFlightButton: some View {
        Button {
            trackThisFlight()
        } label: {
            HStack {
                Spacer()

                Text(currentFlightIsSupported ? "Track This Flight" : "Flight Not Yet Supported")
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
        .disabled(!currentFlightIsSupported)
    }
}

// MARK: - Actions

private extension PlannerView {

    func resetPlanner() {
        autoLookupTask?.cancel()
        lastLookupSignature = nil
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
        isFlightFieldFocused = false
    }

    var normalizedFlightNumber: String {
        flightNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    var currentLookupSignature: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let day = formatter.string(from: flightDate)
        return "\(normalizedFlightNumber)|\(day)"
    }

    func looksLikeValidFlightNumber(_ value: String) -> Bool {
        let compact = value.replacingOccurrences(of: " ", with: "")
        let pattern = #"^[A-Z0-9]{2,3}\d{1,4}[A-Z]?$"#
        return compact.range(of: pattern, options: .regularExpression) != nil
    }

    func scheduleAutoLookupIfNeeded() {
        autoLookupTask?.cancel()

        guard useFlightNumber else { return }

        let candidate = normalizedFlightNumber
        guard looksLikeValidFlightNumber(candidate) else { return }

        let signature = currentLookupSignature
        guard signature != lastLookupSignature else { return }

        autoLookupTask = Task {
            try? await Task.sleep(nanoseconds: 550_000_000)
            if Task.isCancelled { return }

            await lookupFlight(force: false)
        }
    }

    func lookupFlight(force: Bool) async {
        let trimmedFlightNumber = normalizedFlightNumber

        guard !trimmedFlightNumber.isEmpty else { return }
        guard force || looksLikeValidFlightNumber(trimmedFlightNumber) else { return }
        guard !isLookingUpFlight else { return }

        let signature = currentLookupSignature
        guard force || signature != lastLookupSignature else { return }

        errorText = nil
        plan = nil
        flightLookupResult = nil
        isLookingUpFlight = true
        defer { isLookingUpFlight = false }

        do {
            let result = try await flightLookupService.lookupFlight(
                flightNumber: trimmedFlightNumber,
                date: flightDate,
                airportIATA: nil
            )

            if let matchedAirport = flowAirport(from: result.originIATA) {
                store.selectedAirport = matchedAirport
            }

            lastLookupSignature = signature
            flightLookupResult = result
            departureTime = result.departureTime
            isFlightFieldFocused = false

        } catch {
            if force {
                errorText = error.localizedDescription
            }
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

    func trackThisFlight() {
        errorText = nil

        guard let flight = flightLookupResult, let plan else {
            errorText = "Look up a flight and calculate leave time first."
            return
        }

        guard currentFlightIsSupported else {
            errorText = "Flow does not support live airport data for \(flight.originIATA) yet."
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
            status: flight.status,
            departureTime: flight.departureTime,
            leaveTime: plan.recommendedLeaveTime,
            gateTargetTime: plan.gateTargetTime,
            travelMinutes: plan.travelMinutes,
            securityMinutes: plan.securityMinutes,
            airportBufferMinutes: plan.airportBufferMinutes,
            bagBufferMinutes: plan.bagBufferMinutes,
            leaveTimeTrend: LeaveTimeTrend.unchanged,
            securityRouteMode: securitySelection.mode,
            securityRouteID: securitySelection.option.id,
            securityRouteTitle: securitySelection.option.title,
            securityRouteSubtitle: securitySelection.option.subtitle,
            securityRouteDetail: securitySelection.option.detail,
            securityRouteIsPreCheckOnly: securitySelection.option.isPreCheckOnly
        )

        store.setTrackedFlight(tracked)
        selectedTab = .flight
    }

    func flowAirport(from code: String) -> FlowAirport? {
        AirportRegistry.airports
            .map(\.airport)
            .first(where: { $0.rawValue.caseInsensitiveCompare(code) == .orderedSame })
    }

    func displayAirportLine(for code: String) -> String {
        if let airport = flowAirport(from: code) {
            return "\(airport.rawValue) · \(airport.displayName)"
        } else {
            return "\(code) · Not yet supported in Flow"
        }
    }
}

// MARK: - Helpers

private extension PlannerView {

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

    func cleanedRoute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            if minutes > 0 {
                return "Leaving in \(hours)h \(minutes)m"
            } else {
                return "Leaving in \(hours)h"
            }
        } else {
            return "Leaving in \(minutes)m"
        }
    }

    func countdownColor(for leaveTime: Date) -> Color {
        leaveTime.timeIntervalSinceNow <= 0
            ? .red.opacity(0.95)
            : .white.opacity(0.82)
    }
}
