import Foundation

struct EstimatedHourRange: Codable, Hashable {
    let startHour: Int
    let endHour: Int

    func contains(_ hour: Int) -> Bool {
        if startHour <= endHour {
            return hour >= startHour && hour < endHour
        } else {
            return hour >= startHour || hour < endHour
        }
    }
}

struct EstimatedCheckpointSchedule: Codable, Hashable {
    let weekdays: Set<Int>
    let hours: [EstimatedHourRange]

    func isOpen(weekday: Int, hour: Int) -> Bool {
        guard weekdays.contains(weekday) else { return false }
        return hours.contains { $0.contains(hour) }
    }
}

struct EstimatedCheckpointProfile: Codable, Hashable {
    let name: String
    let areaName: String
    let terminal: Int?

    let supportsGeneral: Bool
    let supportsPrecheck: Bool

    let generalBaseMinutes: Int?
    let precheckBaseMinutes: Int?

    let schedules: [EstimatedCheckpointSchedule]
}

struct EstimatedAirportProfile: Codable, Hashable {
    let airport: FlowAirport
    let checkpoints: [EstimatedCheckpointProfile]
}

enum EstimatedAirportProfiles {

    static let defaultSchedules: [EstimatedCheckpointSchedule] = [
        EstimatedCheckpointSchedule(
            weekdays: [1, 2, 3, 4, 5, 6, 7],
            hours: [
                EstimatedHourRange(startHour: 4, endHour: 23)
            ]
        )
    ]

    static let profiles: [FlowAirport: EstimatedAirportProfile] = [

        .cdg: EstimatedAirportProfile(
            airport: .cdg,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 14, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 2", terminal: 2, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 18, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 3", terminal: 3, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 11, precheckBaseMinutes: nil, schedules: defaultSchedules)
            ]
        ),

        .dxb: EstimatedAirportProfile(
            airport: .dxb,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 16, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 2", terminal: 2, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 12, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 3", terminal: 3, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 20, precheckBaseMinutes: nil, schedules: defaultSchedules)
            ]
        ),

        .sin: EstimatedAirportProfile(
            airport: .sin,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 10, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 2", terminal: 2, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 8, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 3", terminal: 3, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 12, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 4", terminal: 4, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 9, precheckBaseMinutes: nil, schedules: defaultSchedules)
            ]
        ),

        .fra: EstimatedAirportProfile(
            airport: .fra,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 15, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 2", terminal: 2, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 13, precheckBaseMinutes: nil, schedules: defaultSchedules)
            ]
        ),

        .mad: EstimatedAirportProfile(
            airport: .mad,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 17, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 2", terminal: 2, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 11, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 4", terminal: 4, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 14, precheckBaseMinutes: nil, schedules: defaultSchedules)
            ]
        ),

        .sfo: EstimatedAirportProfile(
            airport: .sfo,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Checkpoint A", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 14, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint B", areaName: "Terminal 2", terminal: 2, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 12, precheckBaseMinutes: 6, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint C", areaName: "Terminal 3", terminal: 3, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 13, precheckBaseMinutes: 5, schedules: defaultSchedules)
            ]
        ),

        .lax: EstimatedAirportProfile(
            airport: .lax,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 16, precheckBaseMinutes: 7, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "Terminal 4", terminal: 4, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 14, precheckBaseMinutes: 6, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "Terminal 7", terminal: 7, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 15, precheckBaseMinutes: 6, schedules: defaultSchedules)
            ]
        ),

        .ord: EstimatedAirportProfile(
            airport: .ord,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 15, precheckBaseMinutes: 7, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "Terminal 2", terminal: 2, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 12, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "Terminal 3", terminal: 3, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 16, precheckBaseMinutes: 7, schedules: defaultSchedules)
            ]
        ),

        .las: EstimatedAirportProfile(
            airport: .las,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Checkpoint A/B", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 12, precheckBaseMinutes: 5, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint C", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 11, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint E", areaName: "Terminal 3", terminal: 3, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 13, precheckBaseMinutes: 6, schedules: defaultSchedules)
            ]
        ),

        .bos: EstimatedAirportProfile(
            airport: .bos,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "Terminal A", terminal: 1, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 11, precheckBaseMinutes: 5, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "Terminal B", terminal: 2, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 13, precheckBaseMinutes: 6, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "Terminal C", terminal: 3, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 12, precheckBaseMinutes: 5, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "Terminal E", terminal: 4, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 14, precheckBaseMinutes: nil, schedules: defaultSchedules)
            ]
        ),

        .sea: EstimatedAirportProfile(
            airport: .sea,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Checkpoint 1", areaName: "Main Terminal", terminal: 1, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 10, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint 2", areaName: "Main Terminal", terminal: 2, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 12, precheckBaseMinutes: 5, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint 3", areaName: "Main Terminal", terminal: 3, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 13, precheckBaseMinutes: 6, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint 4", areaName: "Main Terminal", terminal: 4, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 11, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint 5", areaName: "Main Terminal", terminal: 5, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 13, precheckBaseMinutes: 6, schedules: defaultSchedules)
            ]
        ),

        .san: EstimatedAirportProfile(
            airport: .san,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 11, precheckBaseMinutes: 5, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "Terminal 2", terminal: 2, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 12, precheckBaseMinutes: 5, schedules: defaultSchedules)
            ]
        ),

        .mia: EstimatedAirportProfile(
            airport: .mia,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "North Terminal", terminal: 1, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 15, precheckBaseMinutes: 7, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "Central Terminal", terminal: 2, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 14, precheckBaseMinutes: 6, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Checkpoint", areaName: "South Terminal", terminal: 3, supportsGeneral: true, supportsPrecheck: true, generalBaseMinutes: 13, precheckBaseMinutes: 6, schedules: defaultSchedules)
            ]
        ),

        .bcn: EstimatedAirportProfile(
            airport: .bcn,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 9, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 2", terminal: 2, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 12, precheckBaseMinutes: nil, schedules: defaultSchedules)
            ]
        ),

        .fco: EstimatedAirportProfile(
            airport: .fco,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 10, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 3", terminal: 3, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 14, precheckBaseMinutes: nil, schedules: defaultSchedules)
            ]
        ),

        .hnd: EstimatedAirportProfile(
            airport: .hnd,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 10, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 2", terminal: 2, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 9, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 3", terminal: 3, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 11, precheckBaseMinutes: nil, schedules: defaultSchedules)
            ]
        ),

        .icn: EstimatedAirportProfile(
            airport: .icn,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 11, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 2", terminal: 2, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 9, precheckBaseMinutes: nil, schedules: defaultSchedules)
            ]
        ),

        .syd: EstimatedAirportProfile(
            airport: .syd,
            checkpoints: [
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 1", terminal: 1, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 12, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 2", terminal: 2, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 10, precheckBaseMinutes: nil, schedules: defaultSchedules),
                EstimatedCheckpointProfile(name: "Security", areaName: "Terminal 3", terminal: 3, supportsGeneral: true, supportsPrecheck: false, generalBaseMinutes: 14, precheckBaseMinutes: nil, schedules: defaultSchedules)
            ]
        )
    ]
}
