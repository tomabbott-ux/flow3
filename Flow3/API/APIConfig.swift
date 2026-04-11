import Foundation

enum APIConfig {

    // MARK: - AeroDataBox (RapidAPI)

    static var aeroDataBoxAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "27ef61402amshd4b5bbfcee3acddp165ba8jsn3570f0182cc9") as? String else {
            fatalError("Missing AERODATABOX_API_KEY in Info.plist")
        }
        return key
    }

    static let aeroDataBoxHost = "aerodatabox.p.rapidapi.com"
}
