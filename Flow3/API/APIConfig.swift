import Foundation

enum APIConfig {

    static var aeroDataBoxAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "AERODATABOX_API_KEY") as? String else {
            fatalError("Missing AERODATABOX_API_KEY in Info.plist")
        }
        return key
    }

    static let aeroDataBoxHost = "aerodatabox.p.rapidapi.com"
}
