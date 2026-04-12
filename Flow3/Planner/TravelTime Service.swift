import Foundation
import MapKit
import CoreLocation

enum TravelTimeServiceError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case routeUnavailable
    case airportLookupFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission is required to calculate travel time."
        case .locationUnavailable:
            return "Could not get your current location."
        case .routeUnavailable:
            return "Directions not available."
        case .airportLookupFailed:
            return "Could not find that airport location."
        }
    }
}

final class TravelTimeService: NSObject, CLLocationManagerDelegate {

    private let locationManager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func drivingMinutes(to airport: FlowAirport) async throws -> Int {
        try await drivingMinutes(to: airport.coordinate, fallbackAirport: airport)
    }

    func drivingMinutes(toAirportCode airportCode: String) async throws -> Int {
        let destinationCoordinate = try await resolveAirportCoordinate(for: airportCode)
        return try await drivingMinutes(to: destinationCoordinate, fallbackAirport: nil)
    }

    func nearestAirport(from airports: [FlowAirport]) async throws -> FlowAirport {
        let userCoordinate = try await currentLocationCoordinate(fallbackAirport: nil)
        let userLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)

        guard let nearest = airports.min(by: { lhs, rhs in
            let lhsLocation = CLLocation(latitude: lhs.coordinate.latitude, longitude: lhs.coordinate.longitude)
            let rhsLocation = CLLocation(latitude: rhs.coordinate.latitude, longitude: rhs.coordinate.longitude)
            return userLocation.distance(from: lhsLocation) < userLocation.distance(from: rhsLocation)
        }) else {
            throw TravelTimeServiceError.locationUnavailable
        }

        return nearest
    }

    func currentLocationCoordinate() async throws -> CLLocationCoordinate2D {
        try await currentLocationCoordinate(fallbackAirport: nil)
    }

    private func drivingMinutes(
        to destinationCoordinate: CLLocationCoordinate2D,
        fallbackAirport: FlowAirport?
    ) async throws -> Int {
        let userCoordinate = try await currentLocationCoordinate(fallbackAirport: fallbackAirport)

        let request = MKDirections.Request()
        request.source = MKMapItem(
            placemark: MKPlacemark(coordinate: userCoordinate)
        )
        request.destination = MKMapItem(
            placemark: MKPlacemark(coordinate: destinationCoordinate)
        )
        request.transportType = .automobile

        let response = try await MKDirections(request: request).calculate()

        guard let route = response.routes.first else {
            throw TravelTimeServiceError.routeUnavailable
        }

        return Int(ceil(route.expectedTravelTime / 60.0))
    }

    private func resolveAirportCoordinate(for airportCode: String) async throws -> CLLocationCoordinate2D {
        let cleanedCode = airportCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !cleanedCode.isEmpty else {
            throw TravelTimeServiceError.airportLookupFailed
        }

        let queries = [
            "\(cleanedCode) airport",
            "\(cleanedCode) international airport",
            "\(cleanedCode) terminal"
        ]

        for query in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query

            let response = try await MKLocalSearch(request: request).start()

            if let best = bestAirportMatch(from: response.mapItems, airportCode: cleanedCode) {
                return best.placemark.coordinate
            }

            if let first = response.mapItems.first {
                return first.placemark.coordinate
            }
        }

        throw TravelTimeServiceError.airportLookupFailed
    }

    private func bestAirportMatch(from items: [MKMapItem], airportCode: String) -> MKMapItem? {
        let upperCode = airportCode.uppercased()

        if let directCodeMatch = items.first(where: { item in
            let name = item.name?.uppercased() ?? ""
            let title = item.placemark.title?.uppercased() ?? ""
            return name.contains(upperCode) || title.contains(upperCode)
        }) {
            return directCodeMatch
        }

        if let airportPOI = items.first(where: { item in
            item.pointOfInterestCategory == .airport
        }) {
            return airportPOI
        }

        return items.first
    }

    private func currentLocationCoordinate(fallbackAirport: FlowAirport?) async throws -> CLLocationCoordinate2D {
#if targetEnvironment(simulator)
        if let existing = locationManager.location?.coordinate {
            return existing
        } else {
            return simulatorFallbackCoordinate(for: fallbackAirport)
        }
#else
        let status = locationManager.authorizationStatus

        if status == .denied || status == .restricted {
            throw TravelTimeServiceError.permissionDenied
        }

        if let existing = locationManager.location?.coordinate {
            return existing
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            switch self.locationManager.authorizationStatus {
            case .notDetermined:
                self.locationManager.requestWhenInUseAuthorization()

            case .authorizedWhenInUse, .authorizedAlways:
                self.locationManager.requestLocation()

            case .denied, .restricted:
                continuation.resume(throwing: TravelTimeServiceError.permissionDenied)

            @unknown default:
                continuation.resume(throwing: TravelTimeServiceError.locationUnavailable)
            }
        }
#endif
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation else { return }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if let existing = manager.location?.coordinate {
                self.continuation = nil
                continuation.resume(returning: existing)
            } else {
                manager.requestLocation()
            }

        case .denied, .restricted:
            self.continuation = nil
            continuation.resume(throwing: TravelTimeServiceError.permissionDenied)

        case .notDetermined:
            break

        @unknown default:
            self.continuation = nil
            continuation.resume(throwing: TravelTimeServiceError.locationUnavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation else { return }

        if let coordinate = locations.last?.coordinate {
            self.continuation = nil
            continuation.resume(returning: coordinate)
        } else {
            self.continuation = nil
            continuation.resume(throwing: TravelTimeServiceError.locationUnavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(throwing: TravelTimeServiceError.locationUnavailable)
    }

    private func simulatorFallbackCoordinate(for airport: FlowAirport?) -> CLLocationCoordinate2D {
        if let airport {
            switch airport {
            case .atl:
                return CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880)
            case .lhr:
                return CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
            default:
                return airport.coordinate
            }
        }

        return CLLocationCoordinate2D(latitude: 51.4700, longitude: -0.4543)
    }
}
