import Foundation

@MainActor
extension LandingStore {

    func applyStartupAirportSelectionIfNeeded() async {
        guard trackedFlight == nil else { return }

        let service = TravelTimeService()

        guard let nearest = try? await service.nearestAirport(
            from: AirportRegistry.airports.map(\.airport)
        ) else {
            return
        }

        if selectedAirport != nearest {
            selectedAirport = nearest
        }
    }
}
