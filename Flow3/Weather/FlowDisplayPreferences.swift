import Foundation
import SwiftUI

final class FlowDisplayPreferences: ObservableObject {

    static let shared = FlowDisplayPreferences()

    @AppStorage("flow.timeFormat") var timeFormatRawValue: String = "twentyFourHour"
    @AppStorage("flow.temperatureUnit") var temperatureUnitRawValue: String = "celsius"

    var usesTwelveHourTime: Bool {
        timeFormatRawValue == "twelveHour"
    }

    var usesFahrenheit: Bool {
        temperatureUnitRawValue == "fahrenheit"
    }

    func timeString(for date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = usesTwelveHourTime ? "h:mm a" : "HH:mm"
        return formatter.string(from: date)
    }

    func temperatureString(fromCelsius celsius: Int) -> String {
        if usesFahrenheit {
            let fahrenheit = Int(round((Double(celsius) * 9.0 / 5.0) + 32.0))
            return "\(fahrenheit)°F"
        } else {
            return "\(celsius)°C"
        }
    }
}
