import Foundation

struct AirportWaitTimeRouter: WaitTimeProviding {

    let atlProvider = ATLStubWaitTimeProvider()
    let lhrProvider = LHRStubWaitTimeProvider()
    let jfkProvider = JFKAzureAPIWaitTimeProvider()
    let amsProvider = AMSWaitTimeProvider()

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        switch airport {

        case .atl:
            return try await atlProvider.fetchWaitTimes(for: airport)

        case .jfk:
            return try await jfkProvider.fetchWaitTimes(for: airport)

        case .lhr:
            return try await lhrProvider.fetchWaitTimes(for: airport)

        case .ams:
            return try await amsProvider.fetchWaitTimes(for: airport)

        case .cdg, .dxb, .sin, .fra, .mad:
            return []
        }
    }
}
