import Foundation

enum APIConfig {

    // MARK: - AeroDataBox (RapidAPI)

    static var aeroDataBoxAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "AERODATABOX_API_KEY") as? String else {
            fatalError("Missing AERODATABOX_API_KEY in Info.plist")
        }
        return key
    }

    static let aeroDataBoxHost = "aerodatabox.p.rapidapi.com"
}
