import Foundation

enum DeparturePlanner {

    static func makePlan(
        departureTime: Date,
        travelMinutes: Int,
        securityMinutes: Int,
        checkedBags: Bool
    ) -> DeparturePlan {

        let airportBufferMinutes = 15
        let bagBufferMinutes = checkedBags ? 20 : 0

        let totalMinutesBeforeDeparture =
            60 + travelMinutes + securityMinutes + airportBufferMinutes + bagBufferMinutes

        let recommendedLeaveTime = Calendar.current.date(
            byAdding: .minute,
            value: -totalMinutesBeforeDeparture,
            to: departureTime
        ) ?? departureTime

        let gateTargetTime = Calendar.current.date(
            byAdding: .minute,
            value: -60,
            to: departureTime
        ) ?? departureTime

        return DeparturePlan(
            recommendedLeaveTime: recommendedLeaveTime,
            gateTargetTime: gateTargetTime,
            travelMinutes: travelMinutes,
            securityMinutes: securityMinutes,
            airportBufferMinutes: airportBufferMinutes,
            bagBufferMinutes: bagBufferMinutes
        )
    }
}
