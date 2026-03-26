import SwiftUI
import VisionKit

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

    @State private var useFlightNumber = true
    @State private var flightNumber = ""
    @State private var flightDate = Date()
    @State private var flightLookupResult: FlightLookupResult?

    @State private var useManualTravelTime = false
    @State private var manualTravelMinutes = 20

    @State private var isShowingBoardingPassScanner = false
    @State private var scannedBoardingPassText: String?

    @State private var autoLookupTask: Task<Void, Never>?
    @State private var lastLookupSignature: String?

    private let travelTimeService = TravelTimeService()
    private let flightLookupService = LiveFlightService()

    var body: some View {
        NavigationStack {
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
            .scrollDismissesKeyboard(.interactively)
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
            .sheet(isPresented: $isShowingBoardingPassScanner) {
                boardingPassScannerSheet
            }
            .onChange(of: useFlightNumber) {
                autoLookupTask?.cancel()
                lastLookupSignature = nil
                errorText = nil
                plan = nil
                flightLookupResult = nil
                isFlightFieldFocused = false
                hideKeyboard()
            }
            .onChange(of: flightNumber) {
                scheduleAutoLookupIfNeeded()
            }
            .onChange(of: flightDate) {
                scheduleAutoLookupIfNeeded()
            }
            .onAppear {
                resetPlannerForSelectedAirport()
            }
            .onChange(of: store.selectedAirport) {
                resetPlannerForSelectedAirport()
            }
            .onDisappear {
                autoLookupTask?.cancel()
            }
        }
    }

    private var canTrackFlight: Bool {
        useFlightNumber &&
        flightLookupResult != nil &&
        plan != nil
    }

    private var airportTitle: String {
        "\(store.selectedAirport.rawValue) search"
    }

    private var airportDescription: String {
        "Search by flight number, scan a boarding pass, or build a manual airport timing plan using live security waits and travel time."
    }

    private var airportDisplayLine: String {
        "\(store.selectedAirport.rawValue) · \(store.selectedAirport.displayName)"
    }

    private var plannerIntroCard: some View {
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

            Text(airportDisplayLine)
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

                Text(airportDisplayLine)
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
                    .submitLabel(.search)
                    .focused($isFlightFieldFocused)
                    .onSubmit {
                        isFlightFieldFocused = false
                        hideKeyboard()

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
                isShowingBoardingPassScanner = true
            } label: {
                HStack {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 15, weight: .bold))

                    Text("Scan Boarding Pass")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(hex: "9B6CFF").opacity(0.22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            if let scannedBoardingPassText, !scannedBoardingPassText.isEmpty {
                Text("Boarding pass scanned")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.68))
            }

            Button {
                isFlightFieldFocused = false
                hideKeyboard()

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

    private var boardingPassScannerSheet: some View {
        ZStack {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                BoardingPassScannerView(
                    onResult: { result in
                        scannedBoardingPassText = result.rawText
                        flightNumber = result.flightNumber
                        if let date = result.flightDate {
                            flightDate = date
                        }
                        isShowingBoardingPassScanner = false
                    },
                    onCancel: {
                        isShowingBoardingPassScanner = false
                    }
                )
                .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Text("Scanner unavailable")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("Boarding pass scanning is not available on this device.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .multilineTextAlignment(.center)

                    Button("Close") {
                        isShowingBoardingPassScanner = false
                    }
                    .foregroundColor(.white)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                )
            }
        }
    }

    private func flightFoundCard(_ flight: FlightLookupResult) -> some View {
        let signal = flight.boardingSignal()

        return VStack(alignment: .leading, spacing: 14) {

            Text("Flight found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            signalCard(signal)

            infoRow("Flight", flight.flightNumber)
            infoRow("Route", "\(flight.originIATA) → \(flight.destinationIATA)")
            infoRow("Airline", flight.airline)

            infoRow("Terminal", displayTerminal(from: flight))
            infoRow("Gate", displayGate(from: flight))

            if let status = cleanedText(flight.status) {
                infoRow("Status", status)
            }

            infoRow("Departure", flightDateTimeString(flight.departureTime))
        }
        .flowGlassCard()
    }

    private func signalCard(_ signal: BoardingSignal) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(signalColor(for: signal.level).opacity(0.18))
                    .frame(width: 34, height: 34)

                Image(systemName: signalIcon(for: signal.level))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(signalColor(for: signal.level))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(signal.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Text(signal.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.74))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(signalColor(for: signal.level).opacity(0.16), lineWidth: 1)
                )
        )
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

    private var travelTimeCard: some View {
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
        dismiss()
    }

    private func resetPlannerForSelectedAirport() {
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
        scannedBoardingPassText = nil
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

    private func signalIcon(for level: BoardingSignalLevel) -> String {
        switch level {
        case .none:
            return "airplane.departure"
        case .headToTerminal:
            return "building.2.fill"
        case .gateAssigned:
            return "mappin.and.ellipse"
        case .boardingLikelySoon:
            return "clock.badge.exclamationmark"
        case .finalCall:
            return "exclamationmark.circle.fill"
        }
    }

    private func signalColor(for level: BoardingSignalLevel) -> Color {
        switch level {
        case .none:
            return .white.opacity(0.85)
        case .headToTerminal:
            return Color(hex: "8EA7FF")
        case .gateAssigned:
            return Color(hex: "9B6CFF")
        case .boardingLikelySoon:
            return .orange.opacity(0.95)
        case .finalCall:
            return .red.opacity(0.95)
        }
    }

    private func displayTerminal(from flight: FlightLookupResult) -> String {
        let cleaned = cleanedText(flight.terminal)
        return cleaned ?? "TBD"
    }

    private func displayGate(from flight: FlightLookupResult) -> String {
        let cleaned = cleanedText(flight.gate)
        return cleaned ?? "TBD"
    }

    private func cleanedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

    private var normalizedFlightNumber: String {
        flightNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private var currentLookupSignature: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let day = formatter.string(from: flightDate)
        return "\(store.selectedAirport.rawValue)|\(normalizedFlightNumber)|\(day)"
    }

    private func looksLikeValidFlightNumber(_ value: String) -> Bool {
        let compact = value.replacingOccurrences(of: " ", with: "")
        let pattern = #"^[A-Z0-9]{2,3}\d{1,4}[A-Z]?$"#
        return compact.range(of: pattern, options: .regularExpression) != nil
    }

    private func scheduleAutoLookupIfNeeded() {
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

    private func lookupFlight(force: Bool) async {
        let trimmedFlightNumber = normalizedFlightNumber

        guard !trimmedFlightNumber.isEmpty else { return }
        guard force || looksLikeValidFlightNumber(trimmedFlightNumber) else { return }

        let signature = currentLookupSignature
        guard force || signature != lastLookupSignature else { return }
        guard !isLookingUpFlight else { return }

        errorText = nil
        plan = nil
        flightLookupResult = nil
        isLookingUpFlight = true
        defer { isLookingUpFlight = false }

        do {
            let result = try await flightLookupService.lookupFlight(
                flightNumber: trimmedFlightNumber,
                date: flightDate,
                airportIATA: store.selectedAirport.rawValue
            )

            lastLookupSignature = signature
            flightLookupResult = result
            departureTime = result.departureTime

        } catch {
            if force {
                errorText = error.localizedDescription
            }
        }
    }

    private func calculate() async {
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
