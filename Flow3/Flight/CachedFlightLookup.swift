import Foundation

struct CachedFlightLookup<T: Codable>: Codable {
    let key: String
    let storedAt: Date
    let value: T

    func isValid(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(storedAt) <= ttl
    }
}
