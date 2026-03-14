import Foundation
import MapKit
import CoreLocation

enum TravelTimeServiceError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case routeUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission is required to calculate travel time to Heathrow."
        case .locationUnavailable:
            return "Could not get your current location."
        case .routeUnavailable:
            return "Could not calculate a driving route to Heathrow."
        }
    }
}

final class TravelTimeService: NSObject, CLLocationManagerDelegate {

    private let locationManager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    private let heathrowCoordinate = CLLocationCoordinate2D(
        latitude: 51.4700,
        longitude: -0.4543
    )

    // London fallback for Simulator / local development
    private let simulatorFallbackCoordinate = CLLocationCoordinate2D(
        latitude: 51.5074,
        longitude: -0.1278
    )

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func drivingMinutesToHeathrow() async throws -> Int {
        let userCoordinate = try await currentLocationCoordinate()

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: heathrowCoordinate))
        request.transportType = .automobile

        let response = try await MKDirections(request: request).calculate()

        guard let route = response.routes.first else {
            throw TravelTimeServiceError.routeUnavailable
        }

        return Int(ceil(route.expectedTravelTime / 60.0))
    }

    private func currentLocationCoordinate() async throws -> CLLocationCoordinate2D {
#if targetEnvironment(simulator)
        // Simulator fallback so development is not blocked by flaky Core Location behaviour
        if let existing = locationManager.location?.coordinate {
            return existing
        } else {
            return simulatorFallbackCoordinate
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
}
