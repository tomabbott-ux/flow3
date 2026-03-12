import Foundation

struct AenaLiveWaitTimeProvider: WaitTimeProviding {

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard let icao = aenaICAO(for: airport) else { return [] }

        async let controlsTask = fetchAccessControls(forICAO: icao)
        async let poisTask = fetchPOIs(forICAO: icao)
        async let buildingsTask = fetchBuildings(forICAO: icao)

        let (controls, pois, buildings) = try await (controlsTask, poisTask, buildingsTask)

        let results: [WaitTimeEstimate] = controls.compactMap { control in

            let poi = pois[control.idpoi]

            let building: AenaBuilding?
            if let poi = poi,
               let buildingID = poi.buildingID {
                building = buildings[buildingID]
            } else {
                building = nil
            }

            let seconds = control.lastWaitSeconds > 0
                ? control.lastWaitSeconds
                : control.defaultWaitSeconds

            let minutes = max(1, Int(ceil(Double(seconds) / 60.0)))

            let checkpointName: String

            if airport == .pmi {
                checkpointName = pmiCheckpointName(for: control.id)
            } else if let poiName = poi?.name,
                      !poiName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                checkpointName = translatedCheckpointName(
                    cleanCheckpointName(poiName, fallbackID: control.id)
                )
            } else {
                checkpointName = buildCheckpointName(from: control.id)
            }

            let areaName: String?
            if airport == .pmi {
                areaName = "Passenger Terminal"
            } else {
                areaName = buildAreaName(from: building, poi: poi)
            }

            return WaitTimeEstimate(
                airport: airport,
                terminal: inferredTerminal(from: building),
                queueType: .general,
                minutes: minutes,
                observedAt: control.expires,
                checkpointName: checkpointName,
                areaName: areaName,
                sourceType: .live,
                isClosed: false
            )
        }

        return results.sorted {
            let lhsCheckpoint = $0.checkpointName ?? ""
            let rhsCheckpoint = $1.checkpointName ?? ""

            if lhsCheckpoint == rhsCheckpoint {
                return ($0.areaName ?? "") < ($1.areaName ?? "")
            }

            return lhsCheckpoint < rhsCheckpoint
        }
    }

    // MARK: - Access Controls

    private func fetchAccessControls(forICAO icao: String) async throws -> [AenaAccessControl] {

        guard let url = URL(
            string: "https://aena-indoor-read-api.geographica.com/api/v1/airports/\(icao)/accesscontrols"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.aena.es/", forHTTPHeaderField: "Referer")
        request.setValue("https://www.aena.es", forHTTPHeaderField: "Origin")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        return json.compactMap { item in

            guard
                let id = item["id"] as? String,
                let idpoi = item["idpoi"] as? String
            else { return nil }

            let lastWait = item["last_wait_s"] as? Int ?? 0
            let defaultWait = item["default_wait_s"] as? Int ?? 0
            let expiresString = item["expires"] as? String ?? ""

            return AenaAccessControl(
                id: id,
                idpoi: idpoi,
                lastWaitSeconds: lastWait,
                defaultWaitSeconds: defaultWait,
                expires: iso8601Date(from: expiresString) ?? Date()
            )
        }
    }

    // MARK: - POIs

    private func fetchPOIs(forICAO icao: String) async throws -> [String: AenaPOI] {

        guard let url = URL(
            string: "https://aena-indoor-read-api.geographica.com/api/v3/pois/\(icao)/list?lang=en"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.aena.es/", forHTTPHeaderField: "Referer")
        request.setValue("https://www.aena.es", forHTTPHeaderField: "Origin")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return [:]
        }

        let object = try JSONSerialization.jsonObject(with: data)

        let features: [[String: Any]]

        if let dict = object as? [String: Any],
           let array = dict["features"] as? [[String: Any]] {
            features = array
        } else if let array = object as? [[String: Any]] {
            features = array
        } else {
            return [:]
        }

        var lookup: [String: AenaPOI] = [:]

        for item in features {

            guard let properties = item["properties"] as? [String: Any],
                  let attrs = properties["attrs"] as? [String: Any],
                  let rawPOI = attrs["pat_id_poi"] else {
                continue
            }

            let idpoi = String(describing: rawPOI)

            let name = firstNonEmptyString(
                attrs["pat_nombre"]
            )

            let terminal = firstNonEmptyString(
                attrs["pat_terminal"]
            )

            let zone = firstNonEmptyString(
                attrs["pat_zonaubicacion"]
            )

            let buildingID = intFromAny(
                properties["building"]
            )

            lookup[idpoi] = AenaPOI(
                idpoi: idpoi,
                name: name,
                terminal: terminal,
                locationName: zone,
                buildingID: buildingID
            )
        }

        return lookup
    }

    // MARK: - Buildings / Terminal layer

    private func fetchBuildings(forICAO icao: String) async throws -> [Int: AenaBuilding] {

        guard let url = URL(
            string: "https://aena-indoor-read-api.geographica.com/api/v1/airports/\(icao)?building_bounds=true&lang=en"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.aena.es/", forHTTPHeaderField: "Referer")
        request.setValue("https://www.aena.es", forHTTPHeaderField: "Origin")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return [:]
        }

        let object = try JSONSerialization.jsonObject(with: data)

        let items: [[String: Any]]

        if let array = object as? [[String: Any]] {
            items = array
        } else if let dict = object as? [String: Any],
                  let array = dict["buildings"] as? [[String: Any]] {
            items = array
        } else if let dict = object as? [String: Any],
                  let array = dict["items"] as? [[String: Any]] {
            items = array
        } else if let dict = object as? [String: Any],
                  let array = dict["results"] as? [[String: Any]] {
            items = array
        } else {
            return [:]
        }

        var lookup: [Int: AenaBuilding] = [:]

        for item in items {

            guard let category = item["category"] as? String,
                  category.uppercased() == "TERMINAL",
                  let id = intFromAny(item["id"]) else {
                continue
            }

            let name = firstNonEmptyString(item["name"])
            let shortName = firstNonEmptyString(item["short_name"])

            lookup[id] = AenaBuilding(
                id: id,
                name: name,
                shortName: shortName
            )
        }

        return lookup
    }

    // MARK: - Mapping

    private func buildCheckpointName(from id: String) -> String {

        let suffix = id.replacingOccurrences(
            of: "^[A-Z]{4}_S0*",
            with: "",
            options: .regularExpression
        )

        if let number = Int(suffix) {
            return "Security \(number)"
        }

        return "Security"
    }

    private func cleanCheckpointName(_ raw: String, fallbackID: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmed.contains("fast lane") {
            return buildCheckpointName(from: fallbackID)
        }

        if trimmed.contains("access to boarding gates") || trimmed.contains("security check") {
            return buildCheckpointName(from: fallbackID)
        }

        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func translatedCheckpointName(_ name: String) -> String {

        let lower = name.lowercased()

        if lower.contains("filtro de conexiones") || lower.contains("connections security") {
            return "Connections"
        }

        if lower.contains("connecting flights") {
            return "Connections"
        }

        if lower.contains("preferential") || lower.contains("family security") {
            return "Family"
        }

        if lower.contains("non-schengen") {
            return "Non-Schengen"
        }

        if lower.contains("security filter") {
            return "Security"
        }

        return name
    }

    private func pmiCheckpointName(for controlID: String) -> String {

        switch controlID {

        case "LEPA_S0001":
            return "Security North"

        case "LEPA_S0002":
            return "Security South"

        case "LEPA_S0003":
            return "Fast Track"

        default:
            return "Security"
        }
    }

    private func buildAreaName(from building: AenaBuilding?, poi: AenaPOI?) -> String? {

        if let building {
            if let name = building.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return name
            }
            if let shortName = building.shortName, !shortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return shortName
            }
        }

        if let terminal = poi?.terminal?.trimmingCharacters(in: .whitespacesAndNewlines),
           !terminal.isEmpty {
            if terminal.lowercased().contains("terminal") {
                return terminal
            } else {
                return "Terminal \(terminal)"
            }
        }

        if let zone = poi?.locationName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !zone.isEmpty {
            let cleaned = zone
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "Zona Restringida", with: "Restricted Area")
                .replacingOccurrences(of: "Zona Publica", with: "Public Area")

            if !cleaned.isEmpty {
                return cleaned
            }
        }

        return nil
    }

    private func inferredTerminal(from building: AenaBuilding?) -> Int? {

        guard let text = (building?.name ?? building?.shortName)?.uppercased() else {
            return nil
        }

        if let digit = text.first(where: { $0.isNumber }) {
            return Int(String(digit))
        }

        return nil
    }

    // MARK: - Airport ICAO

    private func aenaICAO(for airport: FlowAirport) -> String? {
        switch airport {
        case .mad: return "LEMD"
        case .bcn: return "LEBL"
        case .pmi: return "LEPA"
        case .agp: return "LEMG"
        case .alc: return "LEAL"
        case .svq: return "LEZL"
        case .bio: return "LEBB"
        case .ibz: return "LEIB"
        case .vlc: return "LEVC"
        case .tfs: return "GCTS"
        case .lpa: return "GCLP"
        default: return nil
        }
    }

    // MARK: - Helpers

    private func iso8601Date(from string: String) -> Date? {

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: string) {
            return date
        }

        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]

        return fallback.date(from: string)
    }

    private func firstNonEmptyString(_ values: Any?...) -> String? {
        for value in values {
            if let string = value as? String,
               !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return string
            }

            if let number = value as? NSNumber {
                return number.stringValue
            }
        }

        return nil
    }

    private func intFromAny(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }

        if let stringValue = value as? String {
            return Int(stringValue)
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        return nil
    }
}

// MARK: - Models

private struct AenaAccessControl {
    let id: String
    let idpoi: String
    let lastWaitSeconds: Int
    let defaultWaitSeconds: Int
    let expires: Date
}

private struct AenaPOI {
    let idpoi: String
    let name: String?
    let terminal: String?
    let locationName: String?
    let buildingID: Int?
}

private struct AenaBuilding {
    let id: Int
    let name: String?
    let shortName: String?
}
