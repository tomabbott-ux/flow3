import Foundation

struct DeparturePlanner {

    static let gateBufferMinutes = 60
    static let airportBufferMinutes = 15
    static let checkedBagBufferMinutes = 25

    static func makePlan(
        departureTime: Date,
        travelMinutes: Int,
        securityMinutes: Int,
        checkedBags: Bool
    ) -> DeparturePlan {

        let bagBuffer = checkedBags ? checkedBagBufferMinutes : 0

        let gateTargetTime = Calendar.current.date(
            byAdding: .minute,
            value: -gateBufferMinutes,
            to: departureTime
        ) ?? departureTime

        let totalMinutesToSubtract =
            airportBufferMinutes
            + bagBuffer
            + securityMinutes
            + travelMinutes

        let recommendedLeaveTime = Calendar.current.date(
            byAdding: .minute,
            value: -totalMinutesToSubtract,
            to: gateTargetTime
        ) ?? gateTargetTime

        return DeparturePlan(
            departureTime: departureTime,
            gateTargetTime: gateTargetTime,
            recommendedLeaveTime: recommendedLeaveTime,
            travelMinutes: travelMinutes,
            securityMinutes: securityMinutes,
            airportBufferMinutes: airportBufferMinutes,
            bagBufferMinutes: bagBuffer
        )
    }
}
