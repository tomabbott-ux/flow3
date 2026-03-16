import CoreLocation

extension FlowAirport {

    var coordinate: CLLocationCoordinate2D {
        switch self {

        case .atl:
            return CLLocationCoordinate2D(
                latitude: 33.6407,
                longitude: -84.4277
            )

        case .lhr:
            return CLLocationCoordinate2D(
                latitude: 51.4700,
                longitude: -0.4543
            )

        default:
            return CLLocationCoordinate2D(
                latitude: 51.4700,
                longitude: -0.4543
            )
        }
    }
}
