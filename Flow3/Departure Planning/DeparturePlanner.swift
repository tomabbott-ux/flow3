import Foundation

struct DeparturePlan {

    let departureTime: Date
    let gateTargetTime: Date
    let recommendedLeaveTime: Date

    let travelMinutes: Int
    let securityMinutes: Int

    let airportBufferMinutes: Int
    let bagBufferMinutes: Int
}

enum DeparturePlanner {

    // MARK: - Core calculation

    static func makePlan(
        departureTime: Date,
        travelMinutes: Int,
        securityMinutes: Int,
        checkedBags: Bool
    ) -> DeparturePlan {

        let airportBufferMinutes = terminalBufferMinutes()
        let bagBufferMinutes = checkedBags ? bagDropBufferMinutes() : 0

        let gateTargetTime = departureTime
            .addingTimeInterval(-60 * 60) // arrive at gate 60 mins before

        let totalMinutesBeforeGate =
            travelMinutes +
            securityMinutes +
            airportBufferMinutes +
            bagBufferMinutes

        let recommendedLeaveTime = gateTargetTime
            .addingTimeInterval(TimeInterval(-totalMinutesBeforeGate * 60))

        return DeparturePlan(
            departureTime: departureTime,
            gateTargetTime: gateTargetTime,
            recommendedLeaveTime: recommendedLeaveTime,
            travelMinutes: travelMinutes,
            securityMinutes: securityMinutes,
            airportBufferMinutes: airportBufferMinutes,
            bagBufferMinutes: bagBufferMinutes
        )
    }

    // MARK: - Buffers

    private static func terminalBufferMinutes() -> Int {
        // walking time / airport buffer
        return 15
    }

    private static func bagDropBufferMinutes() -> Int {
        // time to drop checked luggage
        return 20
    }
}
