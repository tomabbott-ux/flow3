import Foundation

final class LiveFlightService {

    enum LookupError: LocalizedError {
        case invalidFlightNumber
        case backoffActive
        case invalidResponse
        case flightNotFound(String)

        var errorDescription: String? {
            switch self {

            case .invalidFlightNumber:
                return "Enter a flight number to continue."

            case .backoffActive:
                return "Live flight data isn’t available right now. We’ll keep trying in the background."

            case .invalidResponse:
                return "We’re having trouble loading flight details right now."

            case .flightNotFound:
                return "We couldn’t find that flight. Check the number or try a different date."
            }
        }
    }
    private struct CachedLookupPayload: Codable {
        let flightNumber: String
        let airline: String
        let originIATA: String
        let destinationIATA: String
        let terminal: String?
        let gate: String?
        let status: String?
        let departureTime: Date

        func toResult() -> FlightLookupResult {
            FlightLookupResult(
                flightNumber: flightNumber,
                airline: airline,
                originIATA: originIATA,
                destinationIATA: destinationIATA,
                terminal: terminal,
                gate: gate,
                status: status,
                departureTime: departureTime
            )
        }

        static func from(_ result: FlightLookupResult) -> CachedLookupPayload {
            CachedLookupPayload(
                flightNumber: result.flightNumber,
                airline: result.airline,
                originIATA: result.originIATA,
                destinationIATA: result.destinationIATA,
                terminal: result.terminal,
                gate: result.gate,
                status: result.status,
                departureTime: result.departureTime
            )
        }
    }

    private struct StoredLookupEnvelope: Codable {
        let key: String
        let storedAt: Date
        let payload: CachedLookupPayload

        func isValid(ttl: TimeInterval) -> Bool {
            Date().timeIntervalSince(storedAt) <= ttl
        }
    }

    // MARK: - Keys

    private let aeroDataBoxAPIKey = "326a347895msh7460adc2983b80cp19f5e1jsn6e51a9fd6172"

    // MARK: - Storage

    private let session: URLSession
    private let defaults = UserDefaults.standard
    private let cachePrefix = "flow.liveFlightLookup.cache."
    private let failureBackoffUntilKey = "flow.liveFlightLookup.failureBackoffUntil"

    // MARK: - Init

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public

    func lookupFlight(
        flightNumber: String,
        date: Date,
        airportIATA: String? = nil
    ) async throws -> FlightLookupResult {

        let normalizedFlightNumber = normalizeFlightNumber(flightNumber)
        guard normalizedFlightNumber.count >= 3 else {
            throw LookupError.invalidFlightNumber
        }

        let cleanedAirport = cleanedString(airportIATA)?.uppercased()
        let dateString = requestDateString(from: date)

        let lookupKey = cacheKey(
            flightNumber: normalizedFlightNumber,
            dateString: dateString,
            airportIATA: cleanedAirport ?? "ANY"
        )

        if let cached = loadCachedResult(forKey: lookupKey),
           cached.isValid(ttl: FlightAPIConfig.identicalSearchCacheTTL) {
            await MainActor.run {
                FlightAPIUsageTracker.shared.recordCacheHit()
            }
            return cached.payload.toResult()
        }

        await MainActor.run {
            FlightAPIUsageTracker.shared.recordCacheMiss()
        }

        if isFailureBackoffActive() {
            if let cached = loadCachedResult(forKey: lookupKey) {
                await MainActor.run {
                    FlightAPIUsageTracker.shared.recordCacheHit()
                }
                return cached.payload.toResult()
            }
            throw LookupError.backoffActive
        }

        do {
            let result = try await fetchFromAeroDataBox(
                flightNumber: normalizedFlightNumber,
                dateString: dateString,
                date: date,
                preferredAirportIATA: cleanedAirport
            )

            saveCachedResult(result, forKey: lookupKey)
            clearFailureBackoff()

            return result

        } catch {
            await MainActor.run {
                FlightAPIUsageTracker.shared.recordFailure()
            }

            if let cached = loadCachedResult(forKey: lookupKey) {
                return cached.payload.toResult()
            }

            setFailureBackoff()
            throw error
        }
    }

    // MARK: - AeroDataBox

    private func fetchFromAeroDataBox(
        flightNumber: String,
        dateString: String,
        date: Date,
        preferredAirportIATA: String?
    ) async throws -> FlightLookupResult {

        let urlString =
            "https://aerodatabox.p.rapidapi.com/flights/number/\(flightNumber)/\(dateString)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(aeroDataBoxAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("aerodatabox.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        await MainActor.run {
            FlightAPIUsageTracker.shared.recordCall()
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw LookupError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "AeroDataBoxHTTPError",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "AeroDataBox request failed with status \(http.statusCode)."]
            )
        }

        guard let flights = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw LookupError.invalidResponse
        }

        let matchingFlight = bestMatchingAeroFlight(
            from: flights,
            on: date,
            preferredAirportIATA: preferredAirportIATA
        )

        guard let flight = matchingFlight else {
            let preferredText = preferredAirportIATA?.uppercased() ?? "supported airport"
            throw LookupError.flightNotFound(
                "No matching departure found for \(flightNumber) on \(dateString) for \(preferredText)."
            )
        }

        let airline =
            ((flight["airline"] as? [String: Any])?["name"] as? String) ?? "Unknown"

        let departure = flight["departure"] as? [String: Any] ?? [:]
        let arrival = flight["arrival"] as? [String: Any] ?? [:]

        let departureAirport =
            ((departure["airport"] as? [String: Any])?["iata"] as? String) ?? "UNK"

        let arrivalAirport =
            ((arrival["airport"] as? [String: Any])?["iata"] as? String) ?? "UNK"

        let terminal = cleanedString(departure["terminal"] as? String)
        let gate = cleanedString(departure["gate"] as? String)
        let status = cleanedString(flight["status"] as? String)

        let scheduledLocal =
            ((departure["scheduledTime"] as? [String: Any])?["local"] as? String) ?? ""

        let revisedLocal =
            ((departure["revisedTime"] as? [String: Any])?["local"] as? String)

        guard let scheduledDate = parseAeroDate(scheduledLocal) else {
            throw NSError(
                domain: "DateError",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Could not read scheduled departure time."]
            )
        }

        let revisedDate = revisedLocal.flatMap { parseAeroDate($0) }

        let shownDepartureDate: Date
        if let revisedDate, revisedDate > scheduledDate {
            shownDepartureDate = revisedDate
        } else {
            shownDepartureDate = scheduledDate
        }

        return FlightLookupResult(
            flightNumber: flightNumber,
            airline: airline,
            originIATA: departureAirport,
            destinationIATA: arrivalAirport,
            terminal: terminal,
            gate: gate,
            status: status,
            departureTime: shownDepartureDate
        )
    }

    private func bestMatchingAeroFlight(
        from flights: [[String: Any]],
        on date: Date,
        preferredAirportIATA: String?
    ) -> [String: Any]? {

        let calendar = Calendar(identifier: .gregorian)

        let sameDayFlights = flights.filter { flight in
            guard
                let departure = flight["departure"] as? [String: Any],
                let scheduledLocal = ((departure["scheduledTime"] as? [String: Any])?["local"] as? String),
                let scheduledDate = parseAeroDate(scheduledLocal)
            else {
                return false
            }

            return calendar.isDate(scheduledDate, inSameDayAs: date)
        }

        guard !sameDayFlights.isEmpty else {
            return nil
        }

        if let preferredAirportIATA {
            if let exactPreferred = sameDayFlights.first(where: { flight in
                departureAirportIATA(from: flight)?.uppercased() == preferredAirportIATA.uppercased()
            }) {
                return exactPreferred
            }
        }

        let supportedAirportCodes = Set(
            AirportRegistry.airports.map { $0.airport.rawValue.uppercased() }
        )

        if let supportedMatch = sameDayFlights.first(where: { flight in
            guard let code = departureAirportIATA(from: flight)?.uppercased() else { return false }
            return supportedAirportCodes.contains(code)
        }) {
            return supportedMatch
        }

        return sameDayFlights.first
    }

    // MARK: - Cache / Backoff

    private func cacheKey(
        flightNumber: String,
        dateString: String,
        airportIATA: String
    ) -> String {
        "\(flightNumber)|\(dateString)|\(airportIATA)"
    }

    private func storageKey(for lookupKey: String) -> String {
        cachePrefix + lookupKey
    }

    private func loadCachedResult(forKey lookupKey: String) -> StoredLookupEnvelope? {
        let key = storageKey(for: lookupKey)

        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(StoredLookupEnvelope.self, from: data)
        else {
            return nil
        }

        return decoded
    }

    private func saveCachedResult(_ result: FlightLookupResult, forKey lookupKey: String) {
        let envelope = StoredLookupEnvelope(
            key: lookupKey,
            storedAt: Date(),
            payload: CachedLookupPayload.from(result)
        )

        if let data = try? JSONEncoder().encode(envelope) {
            defaults.set(data, forKey: storageKey(for: lookupKey))
        }
    }

    private func isFailureBackoffActive() -> Bool {
        guard let until = defaults.object(forKey: failureBackoffUntilKey) as? Date else {
            return false
        }

        let remaining = until.timeIntervalSinceNow

        if remaining > 0 {
            print("⏳ Flight API backoff active for \(Int(remaining))s")
            return true
        }

        return false
    }
    private func setFailureBackoff() {
        let until = Date().addingTimeInterval(FlightAPIConfig.failureBackoffInterval)
        defaults.set(until, forKey: failureBackoffUntilKey)

        print("⛔️ Flight API backoff set until:", until)
    }
    
    private func clearFailureBackoff() {
        defaults.removeObject(forKey: failureBackoffUntilKey)
    }

    // MARK: - Helpers

    private func normalizeFlightNumber(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }

    private func requestDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func parseAeroDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "yyyy-MM-dd HH:mmXXXXX",
            "yyyy-MM-dd HH:mmZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mmXXXXX"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private func cleanedString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "—" {
            return nil
        }
        return trimmed
    }

    private func departureAirportIATA(from flight: [String: Any]) -> String? {
        let departure = flight["departure"] as? [String: Any]
        let airport = departure?["airport"] as? [String: Any]
        return cleanedString(airport?["iata"] as? String)
    }
}
