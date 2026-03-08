import Foundation

extension FlowAirport {

    // Airports that should use TSA Average wait scraping
    var isTSAAverageAirport: Bool {
        switch self {

        case .san,
             .las,
             .bos,
             .sea,
             .mia:
            return true

        default:
            return false
        }
    }

    // TSA WaitTimes page URLs
    var tsaAverageURL: URL? {
        switch self {

        case .san:
            return URL(string: "https://www.tsawaittimes.com/security-wait-times/SAN/San-Diego-International")

        case .las:
            return URL(string: "https://www.tsawaittimes.com/security-wait-times/LAS/McCarran-International")

        case .bos:
            return URL(string: "https://www.tsawaittimes.com/security-wait-times/BOS/Logan-International")

        case .sea:
            return URL(string: "https://www.tsawaittimes.com/security-wait-times/SEA/Seattle-Tacoma-International")

        case .mia:
            return URL(string: "https://www.tsawaittimes.com/security-wait-times/MIA/Miami-International")

        default:
            return nil
        }
    }
}
