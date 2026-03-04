import Foundation

struct CompositeWaitTimeProvider: WaitTimeProviding {

    let providers: [WaitTimeProviding]

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        var results: [WaitTimeEstimate] = []

        for provider in providers {
            do {
                let data = try await provider.fetchWaitTimes(for: airport)
                results.append(contentsOf: data)
            } catch {
                // ✅ Don’t let one provider kill the whole refresh
                // You can log it if you want:
                // print("Provider failed for \(airport): \(error)")
                continue
            }
        }

        return results
    }
}
